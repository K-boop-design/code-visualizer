import SwiftUI

struct LearnView: View {
    let learningData: LearnData

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                strategySection
                lessonsSection
                skillsSection
                if let next = learningData.recommendedNext, !next.isEmpty {
                    nextStepsSection(next)
                }
            }
            .padding()
        }
    }

    private var headerSection: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(colors: [.accentColor, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 48, height: 48)
                Image(systemName: "graduationcap.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Kaggle Learning Plan")
                    .font(.title2.weight(.bold))
                HStack(spacing: 12) {
                    Label(learningData.masteryLevel, systemImage: "chart.bar.fill")
                        .font(.caption.weight(.medium))
                        .foregroundColor(masteryColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(masteryColor.opacity(0.12))
                        .cornerRadius(4)
                    Label("\(learningData.totalStages) stages", systemImage: "square.stack.3d.up")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var masteryColor: Color {
        switch learningData.masteryLevel {
        case "Advanced": return .orange
        case "Intermediate": return .blue
        case "Beginner": return .green
        default: return .gray
        }
    }

    private var strategySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Competition Strategy", systemImage: "target")
                .font(.headline)
                .foregroundColor(.primary)
            Text(learningData.competitionStrategy)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentColor.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var lessonsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Skills Breakdown", systemImage: "book.fill")
                .font(.headline)
                .foregroundColor(.primary)

            ForEach(learningData.lessons) { lesson in
                LessonCard(lesson: lesson)
            }
        }
    }

    private func nextStepsSection(_ next: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Recommended Next", systemImage: "arrow.up.forward")
                .font(.headline)
                .foregroundColor(.primary)
            ForEach(next, id: \.self) { step in
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.accentColor)
                        .font(.caption)
                    Text(step)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Skills Progress", systemImage: "chart.bar.fill")
                .font(.headline)
                .foregroundColor(.primary)
            VStack(spacing: 6) {
                ForEach(learningData.skillProgress) { skill in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(difficultyColor(skill.difficulty))
                            .frame(width: 10, height: 10)
                        Text(skill.skill)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(skill.difficulty)
                            .font(.caption2.weight(.medium))
                            .foregroundColor(difficultyColor(skill.difficulty))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(difficultyColor(skill.difficulty).opacity(0.12))
                            .cornerRadius(4)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
        }
    }

    private func difficultyColor(_ d: String) -> Color {
        switch d {
        case "Beginner": return .green
        case "Intermediate": return .blue
        case "Advanced": return .orange
        default: return .gray
        }
    }
}

struct LessonCard: View {
    let lesson: LearnLesson

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.spring(response: 0.35)) { expanded.toggle() } }) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(diffColor)
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lesson.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        Text(lesson.learningOutcome)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(lesson.difficulty)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(diffColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(diffColor.opacity(0.12))
                        .cornerRadius(4)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)
            .padding(14)

            if expanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .padding(.horizontal, 14)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(lesson.explanation)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(2)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.accentColor)
                                Text("Kaggle Skill: \(lesson.kaggleSkill)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.accentColor)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Pro Tips")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.primary)
                                    .padding(.top, 4)
                                ForEach(lesson.tips, id: \.self) { tip in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.green)
                                            .padding(.top, 1)
                                        Text(tip)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            expanded ? diffColor.opacity(0.3) : Color.secondary.opacity(0.1),
                            lineWidth: expanded ? 1.5 : 1
                        )
                )
        )
    }

    private var diffColor: Color {
        switch lesson.difficulty {
        case "Beginner": return .green
        case "Intermediate": return .blue
        case "Advanced": return .orange
        default: return .gray
        }
    }
}
