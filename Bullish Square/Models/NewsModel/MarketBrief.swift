//
//  MarketBrief.swift
//  Bullish Square
//
//  Created by Javier Gomez on 11/2/26.
//

import Foundation

///"Why markets moved": a few lines the server has Claude write from the day's Markets and
///Economy stories, each citing the stories it rests on. (BS-241, BS-242)
struct MarketBrief {
    struct Line {
        let text: String
        ///Numbers into `stories`, from 1, as the card shows them.
        let sources: [Int]
    }

    struct Story {
        let headline: String
        let link: String
        ///Who published it: "CNBC".
        let source: String
    }

    let generatedAt: Date
    let lines: [Line]
    ///Only the stories the lines cite, in the order first cited.
    let stories: [Story]
}
