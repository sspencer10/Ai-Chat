import SwiftUI
import Contacts

struct ContactsView: View {
    @Environment(\.dismiss) var dismiss // Dismiss environment variable
    @State private var contacts: [Contact] = []
    @State private var filteredContacts: [Contact] = [] // Filtered contacts for search
    @State private var phoneNumber: String = ""
    @State private var searchQuery: String = "" // State for search input
    @State private var isPermissionDenied: Bool = false
    @ObservedObject var contentClass: ContentClass
    @StateObject var userDefaultsManager = UserDefaultsManager()

    var body: some View {
        NavigationView {
            VStack {
                if isPermissionDenied {
                    Text("Permission Denied. Please enable Contacts access in Settings.")
                        .padding()
                        .foregroundColor(.red)
                } else {
                    VStack {
                        // Search Bar
                        TextField("Search Contacts", text: $searchQuery)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                            .onChange(of: searchQuery) {
                                filterContacts()
                            }

                        // Contacts List
                        List(filteredContacts) { contact in
                            Button(action: {
                                let number = contact.phone
                                phoneNumber = number.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                                print(phoneNumber) // Output: "3193605046"
                                UserDefaults.standard.set(false, forKey: "showContacts")
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(contact.name)
                                            .font(.headline)
                                        Text(contact.phone)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.vertical, 5)
                            }
                        }
                        .navigationTitle("Contacts")
                        
                        if !phoneNumber.isEmpty {
                            Text("Selected Phone: \(phoneNumber)")
                                .padding()
                                .font(.headline)
                        }
                    }
                }
            }
            .onChange(of: phoneNumber) {
                if !phoneNumber.isEmpty {
                    UserDefaults.standard.set(true, forKey: "waitingForMsg")
                    UserDefaults.standard.set(phoneNumber, forKey: "phone")
                    print("ContentClass instance in ContactsView: \(ObjectIdentifier(contentClass))")
                    print("Before appending: \(contentClass.messages)")
                    // Append the message and dismiss the sheet
                    contentClass.messages.append(Message(content: "What's the message?", isUser: false))
                    print("Before appending: \(contentClass.messages)")
                    dismiss() // Dismiss the sheet
                }
            }
            .onAppear {
                print("ContentClass instance in ContactsView: \(ObjectIdentifier(contentClass))")
                fetchContacts()
            }
        }
    }

    private func fetchContacts() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, error in
            if granted {
                DispatchQueue.global(qos: .userInitiated).async {
                    let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
                    let request = CNContactFetchRequest(keysToFetch: keys)
                    
                    var fetchedContacts: [Contact] = []
                    do {
                        try store.enumerateContacts(with: request) { cnContact, stop in
                            let name = "\(cnContact.givenName) \(cnContact.familyName)"
                            let phone = cnContact.phoneNumbers.first?.value.stringValue ?? "No Phone"
                            fetchedContacts.append(Contact(name: name, phone: phone))
                        }
                        fetchedContacts.sort { $0.name < $1.name }
                        
                        DispatchQueue.main.async {
                            self.contacts = fetchedContacts
                            self.filteredContacts = fetchedContacts // Initialize filteredContacts
                        }
                    } catch {
                        print("Failed to fetch contacts: \(error)")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isPermissionDenied = true
                }
            }
        }
    }

    private func filterContacts() {
        if searchQuery.isEmpty {
            filteredContacts = contacts
        } else {
            filteredContacts = contacts.filter { contact in
                contact.name.lowercased().contains(searchQuery.lowercased()) ||
                contact.phone.contains(searchQuery)
            }
        }
    }
}

struct Contact: Identifiable {
    let id = UUID()
    let name: String
    let phone: String
}

struct ContactsView_Previews: PreviewProvider {
    static var previews: some View {
        ContactsView(contentClass: ContentClass())
    }
}


