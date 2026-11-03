//
//  MarketBrief.swift
//  Bullish Square
//
//  Created by Javier Gomez on 11/2/26.
//

import Foundation

///"Why markets moved": a few lines the server has Claude write from the day's Markets and
///Economy stories, each citing the stories it rests on. (BS-241, BS-242)
///
///Codable so the last one is kept on disk by `NewsCache`.
struct MarketBrief: Codable {
    struct Line: Codable {
        let text: String
        ///Numbers into `stories`, from 1, as the card shows them.
        let sources: [Int]
    }

    struct Story: Codable {
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

///An Ask AI answer (BS-243), in the brief's shape. When the stories do not cover the question,
///`answered` is false and the one line says so, citing nothing.
struct NewsAnswer {
    let answered: Bool
    let lines: [MarketBrief.Line]
    let stories: [MarketBrief.Story]
}
