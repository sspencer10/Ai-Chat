import SwiftUI

struct MessageView: View {
    let message: Message
    @ObservedObject var contentClass: ContentClass
    @State var userDefaultsManager = UserDefaultsManager()
    @Environment(\.colorScheme) var colorScheme


    var body: some View {

        HStack {
                if message.isUser {
                    if message.content.hasPrefix("{") || message.content.hasPrefix("[") {
                        Spacer()
                        Text("JSON data uploaded...")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
                            .onLongPressGesture(minimumDuration: 1.0) {
                                UIPasteboard.general.string = message.content
                                contentClass.triggerToast()
                            }
                            .contextMenu {
                                Button(action: {
                                    UIPasteboard.general.string = message.content
                                    contentClass.triggerToast()
                                }) {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                            }
                    } else {
                        Spacer()
                        Text(message.content)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
                            .onLongPressGesture(minimumDuration: 1.0) {
                                UIPasteboard.general.string = message.content
                                contentClass.triggerToast()
                            }
                            .contextMenu {
                                Button(action: {
                                    UIPasteboard.general.string = message.content
                                    contentClass.triggerToast()
                                }) {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                            }
                    }
                } else {
                    if message.content.contains("<NavigationButton") {
                        let address = UserDefaults.standard.string(forKey: "address")
                        VStack {
                            Button(action: {
                                let link = "https://www.google.com/maps?saddr=My+Location&daddr=\(address ?? "")"
                                print(link)
                                openLink(urlString: link) { x in
                                    print(x)
                                }
                            }) {
                                Text("Start Navigation")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.red)
                                    .cornerRadius(8)
                            }
                            .padding()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .frame(maxWidth: 760, alignment: .leading)
                    } else if message.content.contains("<ContactsButton") {
                        VStack {
                            Button(action: {
                                UserDefaults.standard.set(true, forKey: "showContacts")
                            }) {
                                Text("Select a contact")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.red)
                                    .cornerRadius(8)
                            }
                            .padding()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .frame(maxWidth: 760, alignment: .leading)
                        
                    } else if message.content.contains("<SetAlarmButton") {
                        if let time = extractTime(from: message.content) {
                            VStack {
                                Button(action: {
                                    openLink(urlString: "shortcuts://run-shortcut?name=Add%20Alarm&input=text&text=\(time)") { x in
                                        print(x)
                                    }
                                }) {
                                    Text("Set Alarm for \(time)")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.red)
                                        .cornerRadius(8)
                                }
                                .padding()
                            }
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                            .frame(maxWidth: 760, alignment: .leading)
                        } else {
                            FormattedTextView(message: "Error: failed to extract time from message.")
                                .padding(.vertical)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(10)
                                .frame(maxWidth: 760, alignment: .leading)
                                .contextMenu {
                                    Button(action: {
                                        UIPasteboard.general.string = message.content
                                        contentClass.triggerToast()
                                    }) {
                                        Label("Copy", systemImage: "doc.on.doc")
                                    }
                                }                    }
                    } else if message.content.contains("<SendTextButton") {
                        let number = userDefaultsManager.phone
                        let msg = UserDefaults.standard.string(forKey: "msg") ?? ""
                        VStack {
                            Button(action: {
                                print("number \(number)")
                                print("msg \(msg)")
                                openLink(urlString: "imessage://\(number)&body=\(msg.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") { x in
                                    print(x)
                                }
                                UserDefaults.standard.set(false, forKey: "waitingForMsg")
                                UserDefaults.standard.set("", forKey: "phone")
                            }) {
                                Text("Send Text")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.red)
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .frame(maxWidth: 760, alignment: .leading)
                        
                    } else if message.content.contains("NBA:") || message.content.contains("SCORE:") {
                        // Use the function
                        if let parsedData = parseSportsString(from: message.content) {
                            //let firstTeam = parsedData.firstTeam
                            let firstScore = parsedData.firstScore
                            let firstLogo = parsedData.firstLogo
                            //let secondTeam = parsedData.secondTeam
                            let secondScore = parsedData.secondScore
                            let secondLogo = parsedData.secondLogo
                            VStack {
                                HStack(alignment: .center) {
                                    // First Team VStack
                                    VStack {
                                        AsyncImage(url: URL(string: firstLogo)) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView() // Shows a loading indicator
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 100, height: 100) // Adjust size as needed
                                            case .failure:
                                                Image(systemName: "xmark.circle") // Placeholder on failure
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 100, height: 100)
                                                    .foregroundColor(.red)
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                        Text(firstScore)
                                            .font(.title)
                                            .foregroundColor(.black) // Ensure text is always black
                                    }
                                    
                                    Spacer()
                                    
                                    // VS Label with explicit width and alignment
                                    Text("VS")
                                        .font(.title)
                                        .foregroundColor(.black) // Ensure text is always black
                                        .frame(width: 50) // Ensure the "VS" occupies space
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.black) // Ensure text is visible on lighter backgrounds
                                        .padding(.horizontal)
                                    
                                    Spacer()
                                    
                                    // Second Team VStack
                                    VStack {
                                        AsyncImage(url: URL(string: secondLogo)) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView() // Shows a loading indicator
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 100, height: 100) // Adjust size as needed
                                            case .failure:
                                                Image(systemName: "xmark.circle") // Placeholder on failure
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 100, height: 100)
                                                    .foregroundColor(.red)
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                        Text(secondScore)
                                            .font(.title)
                                            .foregroundColor(.black) // Ensure text is always black
                                    }
                                }
                                .padding()
                            }
                            .padding() // Add padding around the VStack contents
                            .background(Color(.sRGB, red: 0.9, green: 0.9, blue: 0.9, opacity: 1.0))
                            .cornerRadius(10) // Optional: Add rounded corners
                            .shadow(radius: 5) // Optional: Add a shadow
                            .padding(.horizontal) // Add padding around the entire VStack
                            
                        } else {
                            Text("Error")
                        }
                        
                    } else if message.content.contains("<message") {
                        Text("What's the message?")
                            .padding(.vertical)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                            .frame(maxWidth: 760, alignment: .leading)
                            .contextMenu {
                                Button(action: {
                                    UIPasteboard.general.string = message.content
                                    contentClass.triggerToast()
                                }) {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                            }
                    } else if message.content.contains("oaidalleapiprodscus") {
                        // Handle image messages
                        AssistantImageView(imageUrlString: message.content, contentClass: contentClass)
                    } else {
                        FormattedTextView(message: message.content)
                            .padding(.vertical)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                            .frame(maxWidth: 760, alignment: .leading)
                            .contextMenu {
                                Button(action: {
                                    UIPasteboard.general.string = message.content
                                    contentClass.triggerToast()
                                }) {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                            }
                    }
                    Spacer()
                    Spacer()
                    
                }
           
        }
        .id(message.id)
        
    }
    
    func getLatexUrl() -> String {
        if colorScheme == .dark {
            return "https://latex.codecogs.com/png.latex?%5Cfg%7Bwhite%7D%5Chuge"
        } else {
            return "https://latex.codecogs.com/png.latex?%5Cfg%7Bblack%7D%5Chuge"
        }
    }
    
    // Function to parse the input string
    func parseSportsString(from input: String) -> (firstTeam: String, firstScore: String, firstLogo: String, secondTeam: String, secondScore: String, secondLogo: String)? {
        // Split the string into lines
        let lines = input.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        // Ensure there are enough lines for parsing
        guard lines.count >= 4 else { return nil }
        
        // Extract the second line (scores and teams)
        let scoreLine = lines[1]
        
        // Use regex to match the pattern with "**" delimiters
        let pattern = #"(.*?)\s\*\*\s(\d+)\s-\s(.*?)\s\*\*\s(\d+)"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsRange = NSRange(scoreLine.startIndex..<scoreLine.endIndex, in: scoreLine)
        
        guard let match = regex?.firstMatch(in: scoreLine, options: [], range: nsRange),
              let firstTeamRange = Range(match.range(at: 1), in: scoreLine),
              let firstScoreRange = Range(match.range(at: 2), in: scoreLine),
              let secondTeamRange = Range(match.range(at: 3), in: scoreLine),
              let secondScoreRange = Range(match.range(at: 4), in: scoreLine) else {
            return nil
        }
        
        // Extract the matched values
        let firstTeam = String(scoreLine[firstTeamRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let firstScore = String(scoreLine[firstScoreRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let secondTeam = String(scoreLine[secondTeamRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let secondScore = String(scoreLine[secondScoreRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract the logo URLs from the third and fourth lines
        let firstLogo = lines[2].trimmingCharacters(in: .whitespacesAndNewlines)
        let secondLogo = lines[3].trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Debug output
        print("First Team: \(firstTeam)")
        print("First Score: \(firstScore)")
        print("First Logo: \(firstLogo)")
        print("Second Team: \(secondTeam)")
        print("Second Score: \(secondScore)")
        print("Second Logo: \(secondLogo)")
        
        // Return the parsed values as a tuple
        return (firstTeam, firstScore, firstLogo, secondTeam, secondScore, secondLogo)
    }
    
    func openLink(urlString: String, completion: @escaping (String) -> Void) {
        if let url = URL(string: urlString) {
            print("urlString: \(urlString)")
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    completion("Link opened successfully.")
                } else {
                    completion("Failed to open link.")
                }
            }
        } else {
            print("Invalid URL: \(urlString)")
        }
    }

    func extractTime(from content: String) -> String? {
        // Updated pattern to match times like 6:00, 600, or 6
        let pattern = "\\b(\\d{1,2}(:\\d{2})?|\\d{3})\\b"
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsString = content as NSString
        let match = regex?.firstMatch(in: content, options: [], range: NSRange(location: 0, length: nsString.length))
        
        if let match = match, match.numberOfRanges > 0 {
            let rawTime = nsString.substring(with: match.range(at: 1))
            
            // Normalize the time format
            if rawTime.contains(":") {
                // If already in the format 6:00, return as-is
                return rawTime
            } else if rawTime.count == 3 {
                // If in the format 702, split into 7:02
                let hour = String(rawTime.prefix(1))
                let minute = String(rawTime.suffix(2))
                return "\(hour):\(minute)"
            } else if rawTime.count == 1 || rawTime.count == 2 {
                // If just hours like 6 or 12, append ":00"
                return "\(rawTime):00"
            }
        }
        return nil
    }
        
        
    }
 
    struct MessageViewOnMac: View {
        let message: Message
        @ObservedObject var contentClass: ContentClass
        @Environment(\.colorScheme) var colorScheme

        var body: some View {
            HStack {
                if message.isUser {
                    Spacer()
                    Text(message.content)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .frame(maxWidth: 760, alignment: .trailing)
                        .onLongPressGesture(minimumDuration: 1.0) {
                            UIPasteboard.general.string = message.content
                            contentClass.triggerToast()
                        }
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = message.content
                                contentClass.triggerToast()
                            }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }
                } else {
                    if message.content.contains("<SetAlarmButton") {
                        if let time = extractTime(from: message.content) {
                            Button(action: {
                                openLink("shortcuts://run-shortcut?name=Add%20Alarm&input=text&text=\(time)")
                            }) {
                                Text("Set Alarm for \(time)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                            .padding()
                        }
                        
                    } else if message.content.contains("<SendTextButton") {
                        if let number = extractnumber(from: message.content) {
                            if let msg = extractmsg(from: message.content) {
                                Button(action: {
                                    openLink("imessage://\(number)&body=\(msg)")
                                    /*("shortcuts://run-shortcut?name=SendText&input=text&text={\"phone\":\"\(number)\",\"msg\":\"\(msg)\"}")*/
                                    
                                }) {
                                    Text("Send Text")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.blue)
                                        .cornerRadius(8)
                                }
                                .padding()
                            }
                        }
                    } else if message.content.contains("NBA:") || message.content.contains("SCORE:") {
                        // Use the function
                        if let parsedData = parseSportsString(from: message.content) {
                           // let firstTeam = parsedData.firstTeam
                            let firstScore = parsedData.firstScore
                            let firstLogo = parsedData.firstLogo
                            //let secondTeam = parsedData.secondTeam
                            let secondScore = parsedData.secondScore
                            let secondLogo = parsedData.secondLogo
                            VStack {
                                HStack(alignment: .center) {
                                    // First Team VStack
                                    VStack {
                                        AsyncImage(url: URL(string: firstLogo)) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView() // Shows a loading indicator
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 100, height: 100) // Adjust size as needed
                                            case .failure:
                                                Image(systemName: "xmark.circle") // Placeholder on failure
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 100, height: 100)
                                                    .foregroundColor(.red)
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                        Text(firstScore)
                                            .font(.title)
                                            .foregroundColor(.black) // Ensure text is always black
                                    }

                                    Spacer()

                                    // VS Label with explicit width and alignment
                                    Text("VS")
                                        .font(.title)
                                        .foregroundColor(.black) // Ensure text is always black
                                        .frame(width: 50) // Ensure the "VS" occupies space
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.black) // Ensure text is visible on lighter backgrounds
                                        .padding(.horizontal)

                                    Spacer()

                                    // Second Team VStack
                                    VStack {
                                        AsyncImage(url: URL(string: secondLogo)) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView() // Shows a loading indicator
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 100, height: 100) // Adjust size as needed
                                            case .failure:
                                                Image(systemName: "xmark.circle") // Placeholder on failure
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 100, height: 100)
                                                    .foregroundColor(.red)
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                        Text(secondScore)
                                            .font(.title)
                                            .foregroundColor(.black) // Ensure text is always black
                                    }
                                }
                                .padding()
                            }
                            .padding() // Add padding around the VStack contents
                            .background(Color(.sRGB, red: 0.9, green: 0.9, blue: 0.9, opacity: 1.0))
                            .cornerRadius(10) // Optional: Add rounded corners
                            .shadow(radius: 5) // Optional: Add a shadow
                            .padding(.horizontal) // Add padding around the entire VStack
                            
                        } else {
                            Text("Error")
                        }
                    } else if message.content.contains("oaidalleapiprodscus") {
                        // Handle image messages
                        AssistantImageViewOnMac(imageUrlString: message.content, contentClass: contentClass)
                    } else {
                        // Handle text messages
                        FormattedTextView(message: message.content)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                            .frame(maxWidth: 760, alignment: .leading)
                            .onLongPressGesture(minimumDuration: 1.0) {
                                UIPasteboard.general.string = message.content
                                contentClass.triggerToast()
                            }
                            .contextMenu {
                                Button(action: {
                                    UIPasteboard.general.string = message.content
                                    contentClass.triggerToast()
                                }) {
                                    Label("Copy", systemImage: "doc.on.doc")}
                            }
                    }
                }
                Spacer()
                Spacer()
            }
            .id(message.id)
        }
        



        // Function to parse the input string
        func parseSportsString(from input: String) -> (firstTeam: String, firstScore: String, firstLogo: String, secondTeam: String, secondScore: String, secondLogo: String)? {
            // Split the string into lines
            let lines = input.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            // Ensure there are enough lines for parsing
            guard lines.count >= 4 else { return nil }
            
            // Extract the second line (scores and teams)
            let scoreLine = lines[1]
            
            // Use regex to match the pattern with "**" delimiters
            let pattern = #"(.*?)\s\*\*\s(\d+)\s-\s(.*?)\s\*\*\s(\d+)"#
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            let nsRange = NSRange(scoreLine.startIndex..<scoreLine.endIndex, in: scoreLine)
            
            guard let match = regex?.firstMatch(in: scoreLine, options: [], range: nsRange),
                  let firstTeamRange = Range(match.range(at: 1), in: scoreLine),
                  let firstScoreRange = Range(match.range(at: 2), in: scoreLine),
                  let secondTeamRange = Range(match.range(at: 3), in: scoreLine),
                  let secondScoreRange = Range(match.range(at: 4), in: scoreLine) else {
                return nil
            }
            
            // Extract the matched values
            let firstTeam = String(scoreLine[firstTeamRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let firstScore = String(scoreLine[firstScoreRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let secondTeam = String(scoreLine[secondTeamRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let secondScore = String(scoreLine[secondScoreRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Extract the logo URLs from the third and fourth lines
            let firstLogo = lines[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let secondLogo = lines[3].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Debug output
            print("First Team: \(firstTeam)")
            print("First Score: \(firstScore)")
            print("First Logo: \(firstLogo)")
            print("Second Team: \(secondTeam)")
            print("Second Score: \(secondScore)")
            print("Second Logo: \(secondLogo)")
            
            // Return the parsed values as a tuple
            return (firstTeam, firstScore, firstLogo, secondTeam, secondScore, secondLogo)
        }


        
        func extractTime(from content: String) -> String? {
            let pattern = "time=\"(\\d{1,2}:\\d{2})\""
            let regex = try? NSRegularExpression(pattern: pattern)
            let nsString = content as NSString
            let match = regex?.firstMatch(in: content, options: [], range: NSRange(location: 0, length: nsString.length))
            if let match = match, match.numberOfRanges > 1 {
                return nsString.substring(with: match.range(at: 1))
            }
            return nil
        }
        func extractmsg(from content: String) -> String? {
            return UserDefaults.standard.string(forKey: "msg")
        }
        
        func extractnumber(from content: String) -> String? {
            return UserDefaults.standard.string(forKey: "phone")
        }
        
        func getLatexUrl() -> String {
            if colorScheme == .dark {
                return "https://latex.codecogs.com/png.latex?%5Cfg%7Bwhite%7D%5Chuge"
            } else {
                return "https://latex.codecogs.com/png.latex?%5Cfg%7Bblack%7D%5Chuge"
            }
        }
        
        // Open the link when the button is clicked
        func openLink(_ urlString: String) {
            guard let url = URL(string: urlString) else { return }
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                print("Google Maps app is not installed.")
            }
        }
    }
    
