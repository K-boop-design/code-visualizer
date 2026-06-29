import SwiftUI

struct CodeEditorView: View {
    @Binding var code: String
    let isAnalyzing: Bool
    let onAnalyze: () -> Void
    let onClear: () -> Void
    var onOpenNotebook: ((URL) -> Void)?
    var notebookName: String?

    @State private var showSamples = false
    @State private var showFilePicker = false
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Label("Python Code", systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.headline)
                    .foregroundColor(.primary)
                if let name = notebookName {
                    Text(name)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.accentColor)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(4)
                }
                Spacer()
                Button(action: { showSamples.toggle() }) {
                    HStack(spacing: 3) {
                        Image(systemName: "text.alignleft")
                        Text("Samples")
                            .font(.caption)
                    }
                }
                .help("Load a sample script")
                .popover(isPresented: $showSamples) {
                    samplePopover
                }
                Button(action: { showFilePicker = true }) {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.badge.plus")
                        Text("Open Notebook")
                            .font(.caption)
                    }
                }
                .help("Open a .ipynb notebook file")
                Button(action: onClear) {
                    HStack(spacing: 3) {
                        Image(systemName: "trash")
                        Text("Clear")
                            .font(.caption)
                    }
                }
                .disabled(code.isEmpty)
                .help("Clear the code editor")

                Divider()
                    .frame(height: 16)

                Button(action: onAnalyze) {
                    HStack(spacing: 4) {
                        if isAnalyzing {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "eye")
                        }
                        Text("Visualize")
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAnalyzing)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            ZStack(alignment: .topLeading) {
                if code.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Paste or type Python code here")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                        Text("Drop a .ipynb notebook here to analyze it")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                TextEditor(text: $code)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.15),
                                lineWidth: isDropTargeted ? 2 : 1
                            )
                    )
            )
            .padding(8)
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers: providers)
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.init(filenameExtension: "ipynb") ?? .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    onOpenNotebook?(url)
                }
            case .failure(let error):
                print("File picker error: \(error)")
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                if let error = error {
                    print("[Drop] Error loading URL: \(error)")
                    return
                }
                guard let url = url else { return }
                DispatchQueue.main.async {
                    if url.pathExtension.lowercased() == "ipynb" {
                        self.onOpenNotebook?(url)
                    }
                }
            }
        } else {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                if let error = error {
                    print("[Drop] Error loading item: \(error)")
                    return
                }
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    if url.pathExtension.lowercased() == "ipynb" {
                        self.onOpenNotebook?(url)
                    }
                }
            }
        }
        return true
    }

    private var samplePopover: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sample Scripts")
                .font(.headline)
                .padding(.bottom, 4)
            ForEach(SampleCode.allCases, id: \.self) { sample in
                Button(action: {
                    code = sample.code
                    showSamples = false
                    onAnalyze()
                }) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(sample.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                        Text(sample.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(width: 280)
    }
}

enum SampleCode: String, CaseIterable {
    case factorial
    case mlPipeline
    case sorting
    case dataAnalysis

    var title: String {
        switch self {
        case .factorial: return "Recursive Factorial"
        case .mlPipeline: return "ML Pipeline (Kaggle)"
        case .sorting: return "Quick Sort"
        case .dataAnalysis: return "Data Analysis"
        }
    }

    var description: String {
        switch self {
        case .factorial: return "Function with recursion, conditionals"
        case .mlPipeline: return "Train/val split, model, evaluation"
        case .sorting: return "Recursive algorithm with lists"
        case .dataAnalysis: return "Pandas EDA with visualization"
        }
    }

    var code: String {
        switch self {
        case .factorial:
            return """
def factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)

def main():
    num = 5
    result = factorial(num)
    print(f"Factorial of {num} is {result}")
    for i in range(1, 8):
        print(f"{i}! = {factorial(i)}")

main()
"""
        case .mlPipeline:
            return """
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score

data = pd.read_csv('train.csv')
X = data.drop('target', axis=1)
y = data['target']

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)

model = RandomForestClassifier(n_estimators=100)
model.fit(X_train, y_train)

predictions = model.predict(X_test)
accuracy = accuracy_score(y_test, predictions)
print(f"Accuracy: {accuracy:.2f}")
"""
        case .sorting:
            return """
def quick_sort(arr):
    if len(arr) <= 1:
        return arr
    pivot = arr[len(arr) // 2]
    left = [x for x in arr if x < pivot]
    middle = [x for x in arr if x == pivot]
    right = [x for x in arr if x > pivot]
    return quick_sort(left) + middle + quick_sort(right)

def main():
    data = [3, 6, 8, 10, 1, 2, 1]
    print("Original:", data)
    sorted_data = quick_sort(data)
    print("Sorted:", sorted_data)

main()
"""
        case .dataAnalysis:
            return """
import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv('sales.csv')
print(df.head())
print(df.describe())
print(df.isnull().sum())

df = df.dropna()
df['revenue'] = df['price'] * df['quantity']

grouped = df.groupby('category')['revenue'].sum()
print(grouped)

plt.figure(figsize=(10, 6))
grouped.plot(kind='bar')
plt.title('Revenue by Category')
plt.tight_layout()
plt.show()
"""
        }
    }
}
