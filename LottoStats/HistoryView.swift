import SwiftUI

struct HistoryView: View {
    let draws = DrawResult.samples
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(draws) { draw in
                    DrawHistoryRow(draw: draw)
                }
            }
            .padding()
        }
        .navigationTitle("Historia losowań")
    }
}

struct DrawHistoryRow: View {
    let draw: DrawResult
    
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(draw.gameName)
                            .font(.headline)
                        
                        Text(draw.drawDate.formatted(date: .long, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Lotto")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        ForEach(draw.numbers, id: \.self) { number in
                            NumberBall(number: number, style: .lotto, size: 34)
                        }
                    }
                }
                
                if let plusNumbers = draw.plusNumbers {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lotto Plus")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            ForEach(plusNumbers, id: \.self) { number in
                                NumberBall(number: number, style: .plus, size: 34)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
}
