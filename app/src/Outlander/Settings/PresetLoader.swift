//
//  PresetLoader.swift
//  Outlander
//
//  Created by Joseph McBride on 12/17/19.
//  Copyright © 2019 Joe McBride. All rights reserved.
//

import Foundation

struct ColorPreset {
    var name:String
    var color:String
    var backgroundColor:String?
    var presetClass:String?
}

extension GameContext {
   public func presetFor(setting: String) -> ColorPreset? {
        let settingToCheck = setting.lowercased()

        if settingToCheck.count == 0 {
            return nil
        }

        if let preset = self.presets[settingToCheck] {
            return preset
        }

        return nil
    }
}

class PresetLoader {
    func load(_ settings:ApplicationSettings, context: GameContext) {
    }

    func save(_ settings:ApplicationSettings, presets:[String:ColorPreset]) {
    }
}
