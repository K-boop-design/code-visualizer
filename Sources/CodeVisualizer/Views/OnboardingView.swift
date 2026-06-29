import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0
    @State private var appear = false

    private let steps: [OnboardingStep] = [
        OnboardingStep(
            icon: "chevron.left.forwardslash.chevron.right",
            iconTint: .accentColor,
            title: "Write or Paste Python Code",
            detail: "Type Python code in the editor panel, or drag-and-drop a .ipynb notebook file to analyze it."
        ),
        OnboardingStep(
            icon: "flowchart",
            iconTint: .blue,
            title: "Explore the Flowchart",
            detail: "View your code as an interactive flowchart. Tap any node to see its details in the Inspector panel. Pinch to zoom, drag to pan."
        ),
        OnboardingStep(
            icon: "square.stack.3d.up",
            iconTint: .green,
            title: "Discover ML Pipelines",
            detail: "Switch to the Pipeline tab to see detected ML stages. Tap a stage card to view its code with line-by-line explanations."
        ),
        OnboardingStep(
            icon: "list.tree",
            iconTint: .purple,
            title: "Browse the Structure Tree",
            detail: "The Structure tab shows your code's AST tree. Click any node to jump to its source code in the Inspector."
        ),
        OnboardingStep(
            icon: "photo.on.rectangle",
            iconTint: .orange,
            title: "View Notebook Outputs",
            detail: "Notebooks with plots and figures show an Outputs tab. Click the eye icon next to plot commands to see the generated images."
        ),
        OnboardingStep(
            icon: "graduationcap",
            iconTint: .red,
            title: "Learn Kaggle Skills",
            detail: "The Learn tab provides educational content based on your detected pipeline stages, with pro tips and competition strategies."
        ),
    ]

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    HStack {
                        Spacer()
                        Button(action: {
                            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPresented = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Skip onboarding")
                    }

                    stepView(steps[currentStep])
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .id(currentStep)
                        .frame(height: 220)

                    HStack(spacing: 8) {
                        ForEach(Array(steps.indices), id: \.self) { idx in
                            Circle()
                                .fill(idx == currentStep ? Color.accentColor : Color.secondary.opacity(0.25))
                                .frame(width: idx == currentStep ? 8 : 6, height: idx == currentStep ? 8 : 6)
                                .animation(.spring(response: 0.3), value: currentStep)
                        }
                    }

                    HStack(spacing: 12) {
                        Button(action: {
                            withAnimation(.spring(response: 0.4)) {
                                if currentStep > 0 { currentStep -= 1 }
                            }
                        }) {
                            Text("Back")
                                .font(.subheadline.weight(.medium))
                        }
                        .disabled(currentStep == 0)
                        .opacity(currentStep == 0 ? 0.4 : 1)

                        Spacer()

                        if currentStep < steps.count - 1 {
                            Button(action: {
                                withAnimation(.spring(response: 0.4)) {
                                    currentStep += 1
                                }
                            }) {
                                Text("Next")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 24)
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
                                Text("Get Started")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .padding(28)
                .frame(width: 440)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 30, y: 10)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                )
                .scaleEffect(appear ? 1 : 0.9)
                .opacity(appear ? 1 : 0)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        appear = true
                    }
                }

                Spacer()
            }
            .padding(40)
        }
    }

    private func stepView(_ step: OnboardingStep) -> some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(step.iconTint.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: step.icon)
                    .font(.title)
                    .foregroundColor(step.iconTint)
            }

            Text(step.title)
                .font(.title3.weight(.bold))

            Text(step.detail)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
                .padding(.horizontal, 20)
        }
    }
}

private struct OnboardingStep {
    let icon: String
    let iconTint: Color
    let title: String
    let detail: String
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
