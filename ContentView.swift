import SwiftUI
import PhotosUI
import CoreLocation

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var locationType: String = "Manual" // "Manual" or "Automatic"
    @State private var manualStreet: String = ""
    @State private var manualArea: String = ""
    @State private var manualCity: String = ""
    @State private var fetchedLocation: String = ""
    @State private var showSuccessPopup = false
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    Text("Pothole Report")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 20)
                    
                    // Image Picker
                    VStack {
                        Text("Upload a Picture")
                            .font(.headline)
                            .padding(.bottom, 5)
                        
                        PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                            VStack {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)
                                Text("Choose from Gallery")
                                    .font(.body)
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .onChange(of: selectedItem) {
                            Task {
                                if let data = try? await selectedItem?.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    selectedImage = uiImage
                                }
                            }
                        }

                        
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .cornerRadius(12)
                                .shadow(radius: 5)
                                .padding(.top, 10)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Location Input
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Location Details")
                            .font(.headline)
                        
                        Picker("Location Type", selection: $locationType) {
                            Text("Enter Manually").tag("Manual")
                            Text("Fetch Current Location").tag("Automatic")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        
                        if locationType == "Manual" {
                            VStack(alignment: .leading, spacing: 10) {
                                TextField("Street Name", text: $manualStreet)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding(.horizontal)
                                
                                TextField("Area", text: $manualArea)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding(.horizontal)
                                
                                TextField("City", text: $manualCity)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding(.horizontal)
                            }
                        } else {
                            Button(action: {
                                if let userLocation = locationManager.userLocation {
                                    fetchedLocation = "\(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude)"
                                } else {
                                    fetchedLocation = "Unable to fetch location"
                                }
                            }) {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.white)
                                    Text("Fetch Current Location")
                                        .foregroundColor(.white)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            
                            if !fetchedLocation.isEmpty {
                                Text("Fetched Location: \(fetchedLocation)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Submit Button
                    Button(action: submitReport) {
                        Text("Submit Report")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(radius: 3)
                    }
                    .padding(.horizontal)

                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showSuccessPopup) {
                Alert(
                    title: Text("Report Submitted"),
                    message: Text("Thank you for reporting the pothole!"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }


    func submitReport() {
        guard let selectedImage = selectedImage else { return }

        guard let webhookURL = URL(string: "https://webhook.site/404524d4-7e58-4551-a204-22ff30ba8deb") else {
            print("Invalid Webhook URL")
            return
        }



        // Convert image to JPEG data
        guard let imageData = selectedImage.jpegData(compressionQuality: 0.8) else { return }

        let boundary = UUID().uuidString
        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        
        let location = locationType == "Manual" ? "\(manualStreet), \(manualArea), \(manualCity)" : fetchedLocation
        let locationPart = "--\(boundary)\r\nContent-Disposition: form-data; name=\"location\"\r\n\r\n\(location)\r\n"
        body.append(locationPart.data(using: .utf8)!)

        // Add Image Data
        let filename = "pothole.jpg"
        let imagePart = "--\(boundary)\r\nContent-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\nContent-Type: image/jpeg\r\n\r\n"
        body.append(imagePart.data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        // End of Body
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // Send Request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error submitting report: \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("Server Response Code: \(httpResponse.statusCode)")

                if httpResponse.statusCode == 200 {
                    DispatchQueue.main.async {
                        showSuccessPopup = true // Show success alert in UI
                    }
                }
            }
        }.resume()
    }
}

// Location Manager Class
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var userLocation: CLLocation?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            DispatchQueue.main.async {
                self.userLocation = location
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to fetch location: \(error.localizedDescription)")
    }
}

// Preview
#Preview {
    ContentView()
}


