import SwiftUI

struct UITutorialOverlay: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0
    @State private var appear = false

    private let steps: [TutorialStep] = [
        TutorialStep(
            title: "Code Editor",
            detail: "Write or paste Python code in the left panel. You can also drag-and-drop .ipynb notebook files directly onto this area.",
            icon: "chevron.left.forwardslash.chevron.right",
            color: .accentColor,
            targetX: 0.18, targetY: 0.45
        ),
        TutorialStep(
            title: "Visualization Mode",
            detail: "Choose between Full Analysis, Flowchart-only, or Pipeline-only analysis modes from the toolbar at the top.",
            icon: "switch.2",
            color: .blue,
            targetX: 0.35, targetY: 0.08
        ),
        TutorialStep(
            title: "Content Tabs",
            detail: "Switch between Flowchart, Pipeline, Structure, Outputs, and Learn views to explore your code from different angles.",
            icon: "rectangle.topthird.inset.filled",
            color: .purple,
            targetX: 0.50, targetY: 0.12
        ),
        TutorialStep(
            title: "Pipeline View",
            detail: "See detected ML pipeline stages as interactive cards. Click a stage to view its code with line-by-line descriptions and AI explanations.",
            icon: "square.stack.3d.up",
            color: .green,
            targetX: 0.50, targetY: 0.50
        ),
        TutorialStep(
            title: "Inspector Panel",
            detail: "Click any node, control flow element, or pipeline stage to inspect its details. Use the AI Explain buttons to get instant code explanations.",
            icon: "info.circle",
            color: .orange,
            targetX: 0.82, targetY: 0.45
        ),
        TutorialStep(
            title: "AI Settings",
            detail: "Click the gear icon to configure your AI provider and API key. Supports GitHub Models (free), Groq, DeepSeek, OpenAI, and Google Gemini.",
            icon: "gearshape",
            color: .red,
            targetX: 0.92, targetY: 0.08
        ),
    ]

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let step = steps[currentStep]
            let target = CGPoint(x: size.width * step.targetX, y: size.height * step.targetY)

            ZStack {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()

                spotlightPulse(at: target)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: currentStep)

                tooltipCard(step: step, target: target, geometry: size)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: currentStep)

                VStack {
                    Spacer()
                    bottomControls
                        .padding(.bottom, 40)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    appear = true
                }
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func spotlightPulse(at point: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 200, height: 200)
                .position(point)

            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: 2)
                .frame(width: 120, height: 120)
                .position(point)
                .shadow(color: .white.opacity(0.15), radius: 20)

            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                .frame(width: 60, height: 60)
                .position(point)
                .shadow(color: .accentColor.opacity(0.3), radius: 12)
        }
    }

    private func tooltipCard(step: TutorialStep, target: CGPoint, geometry: CGSize) -> some View {
        let cardWidth: CGFloat = 320
        let cardHeight: CGFloat = 180
        let arrowHeight: CGFloat = 16

        let prefersTop = target.y > geometry.height * 0.5
        let prefersLeft = target.x < geometry.width * 0.45

        let cardX: CGFloat
        let cardY: CGFloat
        let arrowEdge: Edge

        if prefersLeft {
            cardX = max(24, target.x + 80)
            arrowEdge = .leading
        } else if target.x > geometry.width * 0.7 {
            cardX = min(geometry.width - cardWidth - 24, target.x - 80)
            arrowEdge = .trailing
        } else {
            cardX = (geometry.width - cardWidth) / 2
            if prefersTop {
                arrowEdge = .top
            } else {
                arrowEdge = .bottom
            }
        }

        if prefersTop {
            cardY = target.y - cardHeight - arrowHeight - 40
        } else {
            cardY = target.y + arrowHeight + 40
        }

        return VStack(spacing: 0) {
            if arrowEdge == .bottom {
                arrowHead(edge: .bottom, color: step.color)
                    .frame(width: 20, height: arrowHeight)
                    .offset(x: target.x - cardX - cardWidth / 2 + (prefersLeft ? -100 : (target.x > geometry.width * 0.7 ? 100 : 0)))
            }

            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(step.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: step.icon)
                        .font(.title3)
                        .foregroundColor(step.color)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(step.title)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)

                    Text(step.detail)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
            }
            .padding(18)
            .frame(width: cardWidth)

            if arrowEdge == .top {
                arrowHead(edge: .top, color: step.color)
                    .frame(width: 20, height: arrowHeight)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 24, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(step.color.opacity(0.2), lineWidth: 1)
                )
        )
        .position(x: cardX + cardWidth / 2, y: cardY + (arrowEdge == .top ? arrowHeight : 0))
        .opacity(appear ? 1 : 0)
    }

    @ViewBuilder
    private func arrowHead(edge: Edge, color: Color) -> some View {
        Path { path in
            switch edge {
            case .top:
                path.move(to: CGPoint(x: 0, y: 16))
                path.addLine(to: CGPoint(x: 10, y: 0))
                path.addLine(to: CGPoint(x: 20, y: 16))
            case .bottom:
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 10, y: 16))
                path.addLine(to: CGPoint(x: 20, y: 0))
            case .leading:
                path.move(to: CGPoint(x: 16, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 10))
                path.addLine(to: CGPoint(x: 16, y: 20))
            case .trailing:
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 16, y: 10))
                path.addLine(to: CGPoint(x: 0, y: 20))
            }
        }
        .fill(color.opacity(0.8))
    }

    private var bottomControls: some View {
        HStack(spacing: 14) {
            Button(action: {
                UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                withAnimation(.easeInOut(duration: 0.3)) {
                    isPresented = false
                }
            }) {
                Text("Skip")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 6) {
                ForEach(Array(steps.indices), id: \.self) { idx in
                    Circle()
                        .fill(idx == currentStep ? Color.accentColor : Color.white.opacity(0.25))
                        .frame(width: idx == currentStep ? 8 : 6, height: idx == currentStep ? 8 : 6)
                        .animation(.spring(response: 0.3), value: currentStep)
                }
            }

            Spacer()

            if currentStep < steps.count - 1 {
                Button(action: {
                    withAnimation(.spring(response: 0.4)) {
                        currentStep += 1
                    }
                }) {
                    HStack(spacing: 6) {
                        Text("Next")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: {
                    UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                        Text("Get Started")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 40)
        .opacity(appear ? 1 : 0)
        .animation(.easeOut.delay(0.3), value: appear)
    }
}

private struct TutorialStep {
    let title: String
    let detail: String
    let icon: String
    let color: Color
    let targetX: CGFloat
    let targetY: CGFloat
}
