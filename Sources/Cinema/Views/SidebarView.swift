import SwiftUI

struct SidebarView: View {
    @Binding var title: String
    @Binding var documentPrompt: String
    var cuts: [StoryboardCut]
    @Binding var pageIndex: Int
    var pageCount: Int
    var addCut: () -> Void
    var deleteCut: (StoryboardCut.ID) -> Void
    var deletePage: (Int) -> Void
    var jumpToCut: (StoryboardCut.ID) -> Void

    private let cutsPerPage = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("タイトル", text: $title)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            DisclosureGroup {
                TextEditor(text: $documentPrompt)
                    .font(.system(size: 12))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 96)
                    .padding(6)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.separator, lineWidth: 0.5)
                    }
            } label: {
                Label("ドキュメントプロンプト", systemImage: "doc.text")
                    .font(.headline)
            }
            .padding(.horizontal, 12)

            List(selection: $pageIndex) {
                Section("ページ") {
                    ForEach(0..<pageCount, id: \.self) { index in
                        let first = index * cutsPerPage + 1
                        let last = min((index + 1) * cutsPerPage, cuts.count)
                        Text("Page \(index + 1)  /  Cut \(first)-\(last)")
                            .tag(index)
                            .contextMenu {
                                Button("このページを削除", role: .destructive) {
                                    deletePage(index)
                                }
                                .disabled(pageCount <= 1)
                            }
                    }
                }

                Section("カット") {
                    ForEach(cuts) { cut in
                        HStack {
                            Image(systemName: cut.imageFileName == nil ? "rectangle" : "photo")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading) {
                                Text("Cut \(cut.cutNumber)")
                                if !cut.situation.isEmpty {
                                    Text(cut.situation)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            jumpToCut(cut.id)
                        }
                        .contextMenu {
                            Button("このカットへ移動") {
                                jumpToCut(cut.id)
                            }

                            Button("このカットを削除", role: .destructive) {
                                deleteCut(cut.id)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Button {
                addCut()
            } label: {
                Label("カットを追加", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .padding([.horizontal, .bottom], 12)
        }
        .frame(minWidth: 220)
    }
}
