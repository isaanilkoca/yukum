//
//  StubError.swift
//  YukumTests
//

import Foundation
@testable import Yukum

// SAHTE SERVİSLER: ViewModel testlerinde gerçek servis yerine kullanılır. İnternet/sunucu gerekmez, cevabı BİZ belirleriz, hangi çağrı yapıldı kaydedilir.
// Bu mümkün çünkü ViewModel'ler somut servise değil sözleşmeye (Services/Protocols/) bağlı.

struct StubError: Error {} // testte "bir şey ters gitti" demek için
