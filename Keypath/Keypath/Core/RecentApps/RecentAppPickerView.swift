//
//  RecentAppPickerView.swift
//  Keypath
//

import AppKit
import SwiftUI

struct RecentAppPickerView: View {
    @Bindable private var manager: RecentAppManager

    init(manager: RecentAppManager = .shared) {
        self.manager = manager
    }

    var body: some View {
        ZStack {
            ConcentricRectangle(corners: .concentric, isUniform: true)
                .fill(.clear)
                .glassEffect(.regular, in: .rect(corners: .concentric))

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Apps")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("Tab / Shift-Tab to cycle · Return to switch · Esc to cancel")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if manager.candidates.isEmpty {
                    ContentUnavailableView {
                        Label("No Recent Apps", systemImage: "rectangle.stack")
                    } description: {
                        Text("Open an app to add it to your recent list.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    candidateList
                }
            }
            .padding(16)
        }
        .frame(width: 440, height: 340)
        .containerShape(.rect(cornerRadius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Recent app picker")
    }

    private var candidateList: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(manager.candidates.enumerated()), id: \.element.processIdentifier) { index, application in
                        candidateRow(application, isSelected: index == manager.selectionIndex)
                            .id(application.processIdentifier)
                            .accessibilityAddTraits(index == manager.selectionIndex ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.never)
            .onAppear {
                scrollToSelection(using: scrollProxy)
            }
            .onChange(of: manager.selectionIndex) { _, _ in
                scrollToSelection(using: scrollProxy)
            }
        }
    }

    private func candidateRow(_ application: NSRunningApplication, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: application.icon ?? NSImage())
                .resizable()
                .interpolation(.high)
                .frame(width: 36, height: 36)

            Text(application.localizedName ?? "Unknown App")
                .font(.body)
                .lineLimit(1)

            Spacer(minLength: 0)

            if isSelected {
                Image(systemName: "return")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ConcentricRectangle(corners: .concentric(minimum: 5), isUniform: true)
                .fill(isSelected ? .blue.opacity(0.3) : .clear)
                .glassEffect(.regular.tint(isSelected ? .blue.opacity(0.35) : .clear), in: .rect(corners: .concentric))
        }
        .contentShape(.rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(application.localizedName ?? "Unknown App")
        .accessibilityValue(isSelected ? "Selected" : "")
    }

    private func scrollToSelection(using proxy: ScrollViewProxy) {
        guard let selectedApplication = manager.selectedApplication else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            proxy.scrollTo(selectedApplication.processIdentifier, anchor: .center)
        }
    }
}

#Preview {
    RecentAppPickerView()
}
