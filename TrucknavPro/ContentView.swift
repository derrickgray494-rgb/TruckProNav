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
    
    func makeUIViewController(context: Context) -> NavigationViewController {
        return NavigationViewController()
    }
    
    func updateUIViewController(_ uiViewController: NavigationViewController, context: Context) {
    }
}

#Preview {
    ContentView()
}
