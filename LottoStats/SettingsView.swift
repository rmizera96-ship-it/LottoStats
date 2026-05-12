import SwiftUI

struct SettingsView: View {
    @ObservedObject var ticketViewModel: TicketViewModel
    
    @State private var showClearTicketsAlert = false
    
    private let repository = LottoRepository.shared
    
    private var apiKeyStatusText: String {
        LottoAPIConfiguration.shouldUseRealAPI ? "Ustawiony" : "Nieustawiony"
    }
    
    private var apiKeyDescriptionText: String {
        if LottoAPIConfiguration.shouldUseRealAPI {
            return "Aplikacja wykryła klucz API w pliku Secrets.plist."
        } else {
            return "Brak klucza API. Aplikacja działa na danych testowych."
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                headerView
                
                dataSourceSection
                
                ticketsSection
                
                accountSection
                
                aboutSection
            }
            .padding()
        }
        .navigationTitle("Ustawienia")
        .alert("Usunąć wszystkie kupony?", isPresented: $showClearTicketsAlert) {
            Button("Usuń", role: .destructive) {
                ticketViewModel.clearAllTickets()
            }
            
            Button("Anuluj", role: .cancel) {}
        } message: {
            Text("Tego działania nie można cofnąć.")
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ustawienia")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Zarządzaj źródłem danych, kuponami i przyszłym kontem użytkownika.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var dataSourceSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Źródło danych")
                    .font(.headline)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(repository.dataSourceName)
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Text("Klucz API: \(apiKeyStatusText)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: LottoAPIConfiguration.shouldUseRealAPI ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(LottoAPIConfiguration.shouldUseRealAPI ? .green : .orange)
                }
                
                Text(apiKeyDescriptionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("Klucz API powinien być przechowywany lokalnie w Secrets.plist i nie powinien trafiać na GitHuba.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var ticketsSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Kupony")
                    .font(.headline)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(ticketViewModel.tickets.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Liczba zapisanych kuponów")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                Button(role: .destructive) {
                    showClearTicketsAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Usuń wszystkie kupony")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.12))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(ticketViewModel.tickets.isEmpty)
                .opacity(ticketViewModel.tickets.isEmpty ? 0.5 : 1)
            }
        }
    }
    
    private var accountSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Konto użytkownika")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "person.crop.circle")
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Logowanie nieaktywne")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("W przyszłości dodamy logowanie i synchronizację kuponów w bazie danych.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                Button {
                    // Tu później podłączymy logowanie, np. Firebase albo Supabase.
                } label: {
                    HStack {
                        Image(systemName: "lock.fill")
                        Text("Zaloguj się — wkrótce")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .foregroundStyle(.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(true)
            }
        }
    }
    
    private var aboutSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("O aplikacji")
                    .font(.headline)
                
                Text("LottoStats")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text("Aplikacja do sprawdzania wyników losowań, analizowania statystyk liczb oraz zapisywania własnych kuponów Lotto.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("Aktualnie aplikacja obsługuje lokalne kupony, Lotto Plus, kupony wielolosowaniowe i warstwę danych przygotowaną pod API LOTTO.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(ticketViewModel: TicketViewModel())
    }
}
