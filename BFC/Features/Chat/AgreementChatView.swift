import SwiftUI
import SwiftData

/// Chat with the labor-agreement expert. Plain bubbles, dark, big input.
struct AgreementChatView: View {
    let employer: Employer
    @Environment(\.modelContext) private var context
    @State private var vm: ChatViewModel?

    var body: some View {
        Group {
            if let vm {
                content(vm: vm)
            } else {
                EmptyHint(systemImage: "doc.questionmark",
                          title: "No agreement",
                          message: "Upload a labor agreement for this employer first.")
            }
        }
        .bfcBackground()
        .navigationTitle("Agreement Q&A")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { if vm == nil { vm = ChatViewModel(employer: employer) } }
    }

    private func content(vm: ChatViewModel) -> some View {
        @Bindable var vm = vm
        let messages = vm.sortedMessages()
        return VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if messages.isEmpty {
                            EmptyHint(systemImage: "bubble.left.and.text.bubble.right",
                                      title: "Ask about your contract",
                                      message: "“What's the OT rate after 8 hours?” • “When does double time kick in?” • “What's the per diem?”")
                        }
                        ForEach(messages) { ChatBubble(message: $0).id($0.id) }
                        if vm.isSending {
                            HStack(spacing: 8) {
                                ProgressView().tint(Theme.accent)
                                Text("Reading the agreement…")
                                    .font(Theme.body(14)).foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .padding(Theme.pad)
                }
                .onChange(of: messages.count) {
                    if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }

            if let error = vm.errorMessage {
                Text(error)
                    .font(Theme.body(14)).foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.pad)
            }

            // Composer
            HStack(spacing: 10) {
                TextField("Ask about your pay…", text: $vm.input, axis: .vertical)
                    .font(Theme.body())
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .frame(minHeight: Theme.tapTarget)
                    .background(Theme.surfaceHigh)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.corner))

                Button {
                    Task { await vm.send(context: context) }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: Theme.tapTarget, height: Theme.tapTarget)
                        .background(vm.canSend ? Theme.accent : Theme.surfaceHigh)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                }
                .disabled(!vm.canSend)
            }
            .padding(Theme.pad)
            .background(Theme.background)
        }
        .sheet(isPresented: $vm.showPaywall) { PaywallView() }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage
    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 6) {
                Text(message.content.asDisplayText)
                    .font(Theme.body(16))
                    .foregroundStyle(isUser ? .black : Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Source sections used — lets the lineman verify the answer.
                if !isUser && !message.sources.isEmpty {
                    Label(message.sources.joined(separator: " • "),
                          systemImage: "doc.text.magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .background(isUser ? Theme.accent : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer(minLength: 40) }
        }
    }
}
