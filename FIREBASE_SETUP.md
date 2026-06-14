# Firebase w LottoStats

Projekt korzysta z:

- Firebase Authentication — logowanie i rejestracja przez e-mail i hasło,
- Cloud Firestore — przechowywanie kuponów użytkownika,
- lokalnego zapisu — aplikacja nadal działa bez konta i bez internetu.

## Pierwsze otwarcie projektu

1. Otwórz `LottoStats.xcodeproj` w Xcode.
2. Poczekaj, aż Swift Package Manager pobierze pakiet `firebase-ios-sdk`.
3. Sprawdź, czy plik `GoogleService-Info.plist` znajduje się w targetcie LottoStats.
4. Uruchom aplikację.
5. W zakładce Ustawienia wybierz „Zaloguj się lub zarejestruj”.

## Struktura danych Firestore

```text
users/{uid}
users/{uid}/tickets/{ticketUUID}
```

Po pierwszym zalogowaniu istniejące lokalne kupony są scalane z kuponami konta i wysyłane do Firestore. Po wylogowaniu aplikacja przełącza się na osobny lokalny tryb gościa.

Reguły bezpieczeństwa użyte w konsoli znajdują się również w pliku `firestore.rules`.
