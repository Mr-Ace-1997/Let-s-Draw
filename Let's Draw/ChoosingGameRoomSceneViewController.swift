//
//  ChoosingGameRoomSceneViewController.swift
//  Let's Draw
//
//  Created by apple on 2017/12/2.
//  Copyright © 2017年 apple. All rights reserved.
//

import UIKit
import os.log

class ChoosingGameRoomSceneViewController: UIViewController {

    // MARK: Properties
    
    @IBOutlet weak var userPhoto: UIImageView!
    @IBOutlet weak var userName: UILabel!
    var me: User?
    var selectedRoomId: Int?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        guard let myPlayerInfo = me else {
            fatalError("No information about this player.")
        }
        userName.text = myPlayerInfo.name
        if let myPlayerPhoto = myPlayerInfo.photo {
            userPhoto.image = myPlayerPhoto
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        switch segue.identifier ?? "" {
        case "CreateGameRoom":
            guard let prepareSceneNavigationController = segue.destination as? UINavigationController, let prepareSceneViewController = prepareSceneNavigationController.topViewController as? PrepareSceneViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }
            prepareSceneViewController.me = self.me
            // create a new room and join it
            self.selectedRoomId = createGameRoom()
            prepareSceneViewController.roomNumber = self.selectedRoomId
            joinGameRoom(roomId: self.selectedRoomId!)
        case "JoinGameRoom":
            guard let prepareSceneNavigationController = segue.destination as? UINavigationController, let prepareSceneViewController = prepareSceneNavigationController.topViewController as? PrepareSceneViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }
            prepareSceneViewController.me = self.me
            // join the selected room
            prepareSceneViewController.roomNumber = self.selectedRoomId
            joinGameRoom(roomId: self.selectedRoomId!)
        default:
            fatalError("Unexpected Segue Identifier; \(String(describing: segue.identifier))")
        }
    }
    
    // unwind navigation
    @IBAction func unwindToChoosingGameRoomScene(sender: UIStoryboardSegue) {
        exitGameRoom(roomId: selectedRoomId!)
    }
 

    // MARK: Actions
    
    @IBAction func searchButtonPressed(_ sender: UIButton) {
        // 按下搜索按钮后，弹出一个对话框用于输入房间号
        let searchRoomAlertController = UIAlertController(title: "搜索房间", message: "", preferredStyle: UIAlertControllerStyle.alert)
        searchRoomAlertController.addTextField {
            (textField: UITextField) -> Void in
            textField.placeholder = "输入房间号"
        }
        let cancelAction = UIAlertAction(title: "取消", style: UIAlertActionStyle.cancel, handler: nil)
        let confirmAction = UIAlertAction(title: "加入", style: UIAlertActionStyle.default, handler: {
            (UIAlertAction) in
            // 提交答案
            if let searchContent =  (searchRoomAlertController.textFields!.first as UITextField?)?.text, let roomId = Int(searchContent) {
                let isGameRoomExist = self.searchGameRoom(roomId: roomId)
                if isGameRoomExist {
                    // enter the room
                    self.selectedRoomId = roomId
                    self.performSegue(withIdentifier: "JoinGameRoom", sender: self)
                } else {
                    
                }
            }
        })
        
        searchRoomAlertController.addAction(cancelAction)
        searchRoomAlertController.addAction(confirmAction)
        self.present(searchRoomAlertController, animated: true, completion: nil)
    }
    
    // MARK: Private Methods
    
    // Ask the server to create a new game room and return the number of the new room.
    private func createGameRoom() -> Int {
        var roomId: Int?
        
        // Connect the server
        let urlPath: String = "http://localhost:3000/tasks/createRoom"
        let params = NSMutableDictionary()
        
        var jsonData:Data? = nil
        do {
            jsonData  = try JSONSerialization.data(withJSONObject: params, options:JSONSerialization.WritingOptions.prettyPrinted)
        } catch {
            fatalError("Wrong post params when trying to creat game room.")
        }
        
        // Use semaphore to send Synchronous request
        let semaphore = DispatchSemaphore(value: 0)
        
        ServerConnectionDelegator.httpPost(urlPath: urlPath, httpBody: jsonData!) {
            (data, error) -> Void in
            if error != nil {
                print(error!)
            } else {
                roomId = (data as! [NSDictionary])[0]["roomId"] as? Int
                print((data as! [NSDictionary])[0]["roomId"] as? Int ?? "Wrong room Id returned from server.")
            }
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        
        guard let resultRoomId = roomId else {
            fatalError("No room Id returned from server.")
        }
        return resultRoomId;
    }
    
    private func joinGameRoom(roomId: Int) {
        
        // Connect the server
        let urlPath: String = "http://localhost:3000/tasks/addPlayerToRoom?roomId=\(roomId)&playerName=\(self.me?.name ?? "unknown")"
        let params = NSMutableDictionary()
        
        var jsonData:Data? = nil
        do {
            jsonData  = try JSONSerialization.data(withJSONObject: params, options:JSONSerialization.WritingOptions.prettyPrinted)
        } catch {
            fatalError("Wrong post params when trying to creat game room.")
        }
        
        // Use semaphore to send Synchronous request
        let semaphore = DispatchSemaphore(value: 0)
        
        ServerConnectionDelegator.httpPut(urlPath: urlPath, httpBody: jsonData!) {
            (data, error) -> Void in
            if error != nil {
                print(error!)
            } else {
                if let ok = (data as! [NSDictionary])[0]["ok"] {
                    print("addPlayer: ok : \(ok)")
                } else {
                    os_log("addPlayer: unexpected response from server.", log: OSLog.default, type: .debug)
                }
            }
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)

    }
    
    private func exitGameRoom(roomId: Int) {
        
        // Connect the server
        let urlPath: String = "http://localhost:3000/tasks/removePlayerFromRoom?roomId=\(roomId)&playerName=\(self.me?.name ?? "unknown")"
        let params = NSMutableDictionary()
        
        var jsonData:Data? = nil
        do {
            jsonData  = try JSONSerialization.data(withJSONObject: params, options:JSONSerialization.WritingOptions.prettyPrinted)
        } catch {
            fatalError("Wrong post params when trying to creat game room.")
        }
        
        // Use semaphore to send Synchronous request
        let semaphore = DispatchSemaphore(value: 0)
        
        ServerConnectionDelegator.httpPut(urlPath: urlPath, httpBody: jsonData!) {
            (data, error) -> Void in
            if error != nil {
                print(error!)
            } else {
                if let ok = (data as! [NSDictionary])[0]["ok"] {
                    print("addPlayer: ok : \(ok)")
                } else {
                    os_log("addPlayer: unexpected response from server.", log: OSLog.default, type: .debug)
                }
            }
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        
    }
    
    private func searchGameRoom(roomId: Int) -> Bool {
        return true
    }
}
