//
//  ViewController.swift
//  demo
//
//  Created by 呵呵哒 on 2023/5/6.
//

import UIKit

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let v = AudioView()
        v.backgroundColor = UIColor.init(red: 0.96, green: 0.96, blue: 0.96, alpha: 1)
        v.layer.cornerRadius = 6.0
        v.setData(urlString: "")
        self.view.addSubview(v)
        
        v.snp.makeConstraints { make in
            make.top.equalTo(200.0)
            make.left.equalTo(12.0)
            make.right.equalTo(-12.0)
            make.height.equalTo(113.0)
        }
    }
    
    
}

/*
class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //dataDict为接口返回的字典数据
        let dataDict = [String:Any]()
        guard let model = modelDataAnalysisForCodable(TestModel.self, dataDict) as? TestModel else {return}
        print(model)
    }


    //MARK: Codable数据解析(这个方法是公用的)
    func modelDataAnalysisForCodable<T: Codable>(_ type: T.Type, _ dataDict: [String:Any]) -> Any? {
        do {
            let data = try JSONSerialization.data(withJSONObject: dataDict, options: [])
            let model = try JSONDecoder().decode(T.self, from: data)
            return model
        } catch let error {
            print("数据模型-\(type)解析错误-\(error)")
            return nil
        }
    }
    
}


//MARK: model
struct TestModel: Codable {
    var code: Int?
    var data: TestDataModel?
    var message: String?
}
struct TestDataModel: Codable {
    var age: Int?
    var name: String?
    var list: [TestDataListModel]?//数组
    var userInfo: TestDataUserInfoModel?
}
struct TestDataListModel: Codable {
    var id: Int?
    var text: String?
}
struct TestDataUserInfoModel: Codable {
    var uid: Int?
    var gender: Int?
    var name: String?
}
*/
