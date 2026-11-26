import SwiftUI

private enum Deletion: Identifiable {
    case days(Int)
    case all

    var id: String {
        switch self {
        case .days(let value): return "days-\(value)"
        case .all: return "all"
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var store: HistoryStore
    @Environment(\.presentationMode) private var presentationMode

    @State private var query = ""
    @State private var localRecords: [HistoryRecord] = []
    @State private var remoteItems: [RemoteItem] = []
    @State private var showDeleteMenu = false
    @State private var pendingDeletion: Deletion?
    @State private var shareURL: URL?
    @State private var toast: String?
    @State private var searchTask: DispatchWorkItem?
    @State private var generation = 0

    let onOpenImage: (String) -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 8) {
                TextField("搜索扫码内容", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                if localRecords.isEmpty && remoteItems.isEmpty {
                    Text("暂无历史记录")
                        .foregroundColor(.secondary)
                        .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(localRecords, id: \.id) { record in
                            localRow(record)
                        }
                        ForEach(remoteItems) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title).foregroundColor(Color(red: 0.10, green: 0.46, blue: 0.82))
                                if let time = item.time {
                                    Text(time).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }

                if let toast = toast {
                    Text(toast)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(6)
                }
            }
            .navigationTitle("历史记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("导出 CSV") { self.exportCSV() }
                        Button("删除历史记录", role: .destructive) { self.showDeleteMenu = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { self.presentationMode.wrappedValue.dismiss() }
                }
            }
            .confirmationDialog("删除历史记录", isPresented: $showDeleteMenu, titleVisibility: .visible) {
                ForEach([15, 30, 60, 90, 180], id: \.self) { days in
                    Button("删除 \(days) 天前") { self.pendingDeletion = .days(days) }
                }
                Button("清空全部历史", role: .destructive) { self.pendingDeletion = .all }
                Button("取消", role: .cancel) {}
            }
            .alert(item: $pendingDeletion) { deletion in
                self.alert(for: deletion)
            }
            .sheet(isPresented: Binding(get: { self.shareURL != nil }, set: { if !$0 { self.shareURL = nil } })) {
                if let url = self.shareURL { ShareSheet(items: [url]) }
            }
        }
        .onAppear { self.localRecords = store.allRecords() }
        .onChange(of: query) { value in
            let term = value.trimmingCharacters(in: .whitespacesAndNewlines)
            self.localRecords = store.search(term)
            self.scheduleRemoteQuery(term)
        }
        .onChange(of: toast) { _ in
            guard self.toast != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { self.toast = nil }
        }
    }

    private func localRow(_ record: HistoryRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(record.barcodeType): \(record.resultText)")
            Text(timestampText(record.timestamp))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            SoundPlayer.copyToClipboard(record.resultText)
            self.toast = "已复制到剪贴板"
            if let path = record.imagePath, ImageStore.image(at: path) != nil {
                self.onOpenImage(path)
            } else {
                self.toast = "无图片记录"
            }
        }
    }

    private func timestampText(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private func scheduleRemoteQuery(_ term: String) {
        generation += 1
        let current = generation
        searchTask?.cancel()
        remoteItems = []
        guard preferences.remoteQueryEnabled, !term.isEmpty else { return }

        let task = DispatchWorkItem {
            RemoteQuery.fetch(baseURL: preferences.remoteQueryURL, query: term) { result in
                DispatchQueue.main.async {
                    guard current == self.generation else { return }
                    switch result {
                    case .success(let items): self.remoteItems = items
                    case .failure: self.toast = "网络查询失败，请稍后重试"
                    }
                }
            }
        }
        searchTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: task)
    }

    private func alert(for deletion: Deletion) -> Alert {
        switch deletion {
        case .days(let days):
            return Alert(
                title: Text("确认删除 \(days) 天前的记录？"),
                message: Text("保留今天及往前 \(days - 1) 天，共 \(days) 个自然日，其余记录及截图将永久删除，不可恢复。"),
                primaryButton: .destructive(Text("确定删除")) { self.perform(deletion) },
                secondaryButton: .cancel(Text("取消删除"))
            )
        case .all:
            return Alert(
                title: Text("确认清空全部历史？"),
                message: Text("所有历史记录及截图将被永久删除，不可恢复。"),
                primaryButton: .destructive(Text("确定删除")) { self.perform(deletion) },
                secondaryButton: .cancel(Text("取消删除"))
            )
        }
    }

    private func perform(_ deletion: Deletion) {
        switch deletion {
        case .days(let days):
            store.deleteOlderThan(days: days)
            toast = "已删除 \(days) 天前的记录"
        case .all:
            store.deleteAll()
            toast = "已清空全部历史"
        }
        localRecords = store.allRecords()
    }

    private func exportCSV() {
        let records = store.allRecords()
        guard !records.isEmpty else {
            toast = "没有可导出的历史记录"
            return
        }
        guard let url = CsvExporter.export(records: records) else {
            toast = "导出 CSV 失败"
            return
        }
        shareURL = url
    }
}
