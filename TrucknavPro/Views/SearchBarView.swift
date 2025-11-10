//
//  SearchBarView.swift
//  TruckNavPro
//

import SwiftUI

struct SearchBarView: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    var onSearch: () -> Void
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search destination", text: $searchText, onCommit: {
                    onSearch()
                })
                .autocapitalization(.none)
                .disableAutocorrection(true)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            if isSearching {
                Button("Cancel") {
                    searchText = ""
                    isSearching = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
//  SearchBarView.swift
//  TrucknavPro
//
//  Created by Derrick Gray on 11/8/25.
//

