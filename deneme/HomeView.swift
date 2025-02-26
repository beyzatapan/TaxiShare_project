
import SwiftUI
import MapKit
import CoreLocation
import FirebaseAuth
import GoogleSignIn

struct HomeView: View {
    @State private var userEmail: String = "Anonim Kullanıcı"
    @State private var fromLocation: String = ""
    @State private var toLocation: String = ""
    @State private var showRouteView = false
    @State private var showAccountView = false
    @State private var activeTab: Int = 0
    @State private var showMatchedView = false
    @State private var userLocation = CLLocationCoordinate2D()  // Kullanıcı konumu
    @State private var region = MKCoordinateRegion( // Harita için varsayılan bölge

        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        ZStack{
            VStack {
                
                
                if let userLocation = locationManager.location {
                    MapViewRepresentable(region: $region, userLocation: userLocation)
                        .frame(height: 1270)
                        .ignoresSafeArea(edges: .top)  // Ekranın üst kısmını kapla
                        .frame(height: UIScreen.main.bounds.height / 2)  // Harita yüksekliği "Nereye" kutusuna kadar
                        .onAppear {
                            region.center = userLocation.coordinate
                        }


                } else {
                    Text("Konumunuz alınıyor...")
                        .font(.title)
                        .foregroundColor(.orange)
                        .frame(height: UIScreen.main.bounds.height / 2.5)
                }
                
                
                // Nereden TextField
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.orange)
                    TextField("Nereden", text: $fromLocation)
                        .frame(minHeight: 35)
                }
                .padding()
                .background(Color.orange.opacity(0.2))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Spacer()
                
                // Nereye TextField
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.orange)
                    TextField("Nereye", text: $toLocation)
                        .frame(minHeight: 35)
                }
                .padding()
                .background(Color.orange.opacity(0.2))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Spacer()
                // Bul Butonu
                Button(action: {
                    showRouteView.toggle()  // RouteView'i aç
                }) {
                    Text("Göster")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                Spacer()
                
                HStack {
                    // Home Button
                    Button(action: {
                        activeTab = 0
                    }) {
                        Image(systemName: "house.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .padding()
                            .foregroundColor(activeTab == 0 ? .orange : .gray)
                    }
                    
                    Spacer()
                    
                    // Match Button
                    Button(action: {
                        activeTab = 1
                        showMatchedView = true
                    }) {
                        Image("Adsız tasarım")
                            .resizable()
                            .clipShape(Circle())
                            .frame(width: 60, height: 60)
                            .padding()
                    }
                    .fullScreenCover(isPresented: $showMatchedView) {
                                    MatchedView()
                                   }
                    Spacer()
                    
                    // Account Button
                    Button(action: {
                        showAccountView = true
                        activeTab = 2
                    }) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .padding()
                            .foregroundColor(activeTab == 2 ? .orange : .gray)
                    }
                }
                .padding(.horizontal)
                .background(Color.white)
                .frame(maxWidth: .infinity, maxHeight: 80) // Alt menü yüksekliği
                .background(Color(.systemGray6)) // Alt menü için arka plan
            }
          
                
            .sheet(isPresented: $showRouteView) {
                // RouteView ekranına geçiş
              //  RouteView(fromLocation: fromLocation, toLocation: toLocation, showRouteView: $showRouteView)   // Binding kullanarak showRouteView'i RouteView'e geçiriyoruz
                RouteView(fromLocation: fromLocation, toLocation: toLocation, showRouteView: $showRouteView)

            }
            .fullScreenCover(isPresented: $showAccountView) {
                AccountView()
                  }
            .onAppear {
                // Kullanıcının mevcut konumunu almak için
                locationManager.requestLocation()  // Konumu güncellemek için istekte bulunuyoruz
                if let location = locationManager.location {
                    userLocation = location.coordinate
                    region.center = userLocation  // Kullanıcının konumunu haritada merkez olarak ayarlıyoruz
                }
                
                // Oturum açmış kullanıcıyı kontrol edin
                   if let currentUser = Auth.auth().currentUser {
                       userEmail = currentUser.email ?? "Anonim Kullanıcı"
                   } else if let googleUser = GIDSignIn.sharedInstance.currentUser {
                       userEmail = googleUser.profile?.email ?? "Anonim Kullanıcı"
                   }
            }
        }
    }
    
    // UIViewControllerRepresentable ile özel MKMapView kullanıyoruz
    struct MapViewRepresentable: UIViewControllerRepresentable {
        @Binding var region: MKCoordinateRegion
        var userLocation: CLLocation

        func makeUIViewController(context: Context) -> MKMapViewController {
            let mapVC = MKMapViewController()
            mapVC.region = region
            mapVC.userLocation = userLocation
            return mapVC
        }
        func updateUIViewController(_ uiViewController: MKMapViewController, context: Context) {
              uiViewController.region = region
              uiViewController.userLocation = userLocation
          }
      }

    class MKMapViewController: UIViewController, MKMapViewDelegate {
        var region: MKCoordinateRegion!
        var userLocation: CLLocation!
        var mapView = MKMapView()

        override func viewDidLoad() {
            super.viewDidLoad()

            mapView.frame = view.bounds
            mapView.delegate = self
            mapView.region = region
            mapView.showsUserLocation = true  // Kullanıcının konumunu göster
            mapView.userTrackingMode = .follow  // Kullanıcıyı takip et
            mapView.mapType = .mutedStandard  // Daha sade bir harita görünümü
            view.addSubview(mapView)

            if let userLocation = userLocation {
                let coordinateRegion = MKCoordinateRegion(center: userLocation.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
                mapView.setRegion(coordinateRegion, animated: true)
            }
        }
    }
    
    // LocationManager sınıfı HomeView içinde tanımlandı
    class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
        private let locationManager = CLLocationManager()
        @Published var location: CLLocation?
        @Published var shouldShowAccountView: Bool = false

        
        override init() {
            super.init()
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()  // Konum güncellemelerini başlat
        }
        
        func requestLocation() {
            locationManager.requestLocation()
        }
        
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            location = locations.first
        }
        
        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            print("Error getting location: \(error)")
        }
    }
}
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView ()
    }
}

