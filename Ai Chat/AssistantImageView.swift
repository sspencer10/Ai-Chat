import SwiftUI

struct AssistantImageView: View {
    let imageUrlString: String
    @ObservedObject var contentClass: ContentClass
    @State private var loadedImage: UIImage? = nil
    @State private var isLoading = false
    @State private var loadFailed = false
    
    var body: some View {
        VStack {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .frame(width: 200, height: 200)
                    .contextMenu {
                        Button(action: {
                            contentClass.saveImageToPhotos(image: image)
                        }) {
                            Label("Save Image", systemImage: "square.and.arrow.down")
                        }
                    }
                    .padding()
            } else if isLoading {
                ProgressView()
                    .frame(width: 200, height: 200)
            } else if loadFailed {
                Text("Failed to load image")
                    .frame(width: 200, height: 200)
            } else {
                // Placeholder before the image starts loading
                Color.gray.opacity(0.2)
                    .frame(width: 200, height: 200)
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    func loadImage() {
        guard let url = URL(string: imageUrlString) else {
            loadFailed = true
            return
        }
        
        isLoading = true
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let data = data, let uiImage = UIImage(data: data) {
                    loadedImage = uiImage
                } else {
                    loadFailed = true
                }
            }
        }.resume()
    }
}

struct AssistantImageViewOnMac: View {
    let imageUrlString: String
    @ObservedObject var contentClass: ContentClass
    @State private var loadedImage: UIImage? = nil
    @State private var isLoading = false
    @State private var loadFailed = false
    
    var body: some View {
        VStack {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .frame(width: 200, height: 200)
                    .onLongPressGesture {
                        contentClass.saveImageToPhotos(image: image)
                    }
                    .padding()
            } else if isLoading {
                ProgressView()
                    .frame(width: 200, height: 200)
            } else if loadFailed {
                Text("Failed to load image")
                    .frame(width: 200, height: 200)
            } else {
                // Placeholder before the image starts loading
                Color.gray.opacity(0.2)
                    .frame(width: 200, height: 200)
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    func loadImage() {
        guard let url = URL(string: imageUrlString) else {
            loadFailed = true
            return
        }
        
        isLoading = true
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let data = data, let uiImage = UIImage(data: data) {
                    loadedImage = uiImage
                } else {
                    loadFailed = true
                }
            }
        }.resume()
    }
}
