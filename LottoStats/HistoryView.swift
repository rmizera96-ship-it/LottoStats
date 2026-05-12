import SwiftUI

struct HistoryView: View {
    let draws = DrawResult.samples
    
    var body: some View {
        List {
            ForEach(draws) { draw in
                VStack(alignment: .leading, spacing: 10) {
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
                    
                    HStack {
                        ForEach(draw.numbers, id: \.self) { number in
                            Text("\(number)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(width: 34, height: 34)
                                .background(Color.blue.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Historia losowań")
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
}
