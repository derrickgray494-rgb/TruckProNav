//
//  ContentView.swift
//  TruckNavPro
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationViewControllerRepresentable()
            .ignoresSafeArea()
    }
}

struct NavigationViewControllerRepresentable: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> UINavigationController {
        let mapViewController = MapViewController()
        let navController = UINavigationController(rootViewController: mapViewController)
        navController.setNavigationBarHidden(true, animated: false)
        return navController
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
    }
}

#Preview {
    ContentView()
}
