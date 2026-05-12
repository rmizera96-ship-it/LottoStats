import SwiftUI

struct NumberFrequency: Identifiable {
    let number: Int
    let count: Int
    
    var id: Int {
        number
    }
    
    static func calculate(from draws: [DrawResult]) -> [NumberFrequency] {
        let allNumbers = draws.flatMap { $0.numbers }
        let groupedNumbers = Dictionary(grouping: allNumbers, by: { $0 })
        
        return groupedNumbers
            .map { NumberFrequency(number: $0.key, count: $0.value.count) }
            .sorted {
                if $0.count == $1.count {
                    return $0.number < $1.number
                } else {
                    return $0.count > $1.count
                }
            }
    }
}

struct StatisticsView: View {
    let draws = DrawResult.samples
    
    private var frequencies: [NumberFrequency] {
        NumberFrequency.calculate(from: draws)
    }
    
    private var maxCount: Int {
        frequencies.map { $0.count }.max() ?? 1
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Najczęstsze liczby")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Ranking na podstawie historii losowań")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                ForEach(frequencies) { item in
                    frequencyRow(item)
                }
            }
            .padding()
        }
        .navigationTitle("Statystyki")
    }
    
    private func frequencyRow(_ item: NumberFrequency) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(item.number)")
                    .font(.headline)
                    .frame(width: 42, height: 42)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Liczba \(item.number)")
                        .font(.headline)
                    
                    Text("Wystąpiła \(item.count) razy")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("\(item.count)x")
                    .font(.headline)
            }
            
            ProgressView(value: Double(item.count), total: Double(maxCount))
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        StatisticsView()
    }
}
