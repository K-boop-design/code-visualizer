import SwiftUI

struct OutputsView: View {
    let images: [NotebookOutputImage]
    let highlightedCellIndex: Int?

    var body: some View {
        if images.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(images) { img in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "photo")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Cell \(img.cellIndex + 1) · Output \(img.outputIndex + 1)")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                if let nsImage = NSImage(contentsOfFile: img.path) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: 640)
                                        .cornerRadius(10)
                                } else {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundColor(.orange)
                                        Text("Could not load image")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(img.cellIndex == highlightedCellIndex
                                        ? Color.accentColor.opacity(0.06)
                                        : Color(nsColor: .controlBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(
                                                img.cellIndex == highlightedCellIndex
                                                    ? Color.accentColor.opacity(0.4)
                                                    : Color.secondary.opacity(0.08),
                                                lineWidth: img.cellIndex == highlightedCellIndex ? 2 : 1
                                            )
                                    )
                                    .shadow(
                                        color: img.cellIndex == highlightedCellIndex
                                            ? Color.accentColor.opacity(0.15)
                                            : Color.black.opacity(0.04),
                                        radius: img.cellIndex == highlightedCellIndex ? 8 : 3,
                                        y: 2
                                    )
                            )
                            .padding(.horizontal, 20)
                            .id(img.id)
                        }
                    }
                    .padding(.vertical, 20)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        scrollToHighlighted(proxy)
                    }
                }
                .onChange(of: highlightedCellIndex) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            scrollToHighlighted(proxy)
                        }
                    }
                }
            }
        }
    }

    private func scrollToHighlighted(_ proxy: ScrollViewProxy) {
        guard let cellIdx = highlightedCellIndex else { return }
        if let target = images.first(where: { $0.cellIndex == cellIdx }) {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(target.id, anchor: .top)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.secondary.opacity(0.06))
                    .frame(width: 80, height: 80)
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            Text("No output images")
                .font(.title3.weight(.semibold))
                .foregroundColor(.secondary)
            Text("Notebook cells did not produce any images")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
