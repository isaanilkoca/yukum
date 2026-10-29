//
//  RoleSelectionView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 28.10.2026.
//

import SwiftUI

struct RoleSelectionView: View {
    
    var body: some View {
        
         // ekranlar arası gecis yönetir dönme okunu kendi koyar
            
            VStack(spacing: 24){
                Text("Nasıl Kayıt Olmak İstersiniz ?").font(.title2).bold()
                
                HStack(spacing: 50){
                    
                    NavigationLink("Yük Veren"){ // buton gibi tap yapınca parantez icindeki ekrana gecer
                        RegisterView() // mevcut kayıt formu kod
                    }.buttonStyle(.borderedProminent) // dolgulu dügme görüntüsü
                    
                    NavigationLink("Taşımacı"){
                        CarrierRegisterView() // gecici , sonra carrierregisterview gelecek
                    }.buttonStyle(.borderedProminent)
                }
              
                
                
                
            }.padding()
            
        
        
        
    }
    
    
}

#Preview {
    RoleSelectionView()
}
