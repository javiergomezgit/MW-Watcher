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

///One of the answers a News card switches between with its pills (BS-250): the brief, or a
///fixed question the server answers ahead for everyone. Codable so `NewsCache` keeps them.
struct CardAnswer: Codable {
    ///The pill: "Tech stocks".
    let label: String
    ///The card's title: "Why markets moved", or the question as written.
    let title: String
    let generatedAt: Date
    ///False when the stories do not cover the question; the one line then says so.
    let answered: Bool
    let lines: [MarketBrief.Line]
    let stories: [MarketBrief.Story]
}

extension CardAnswer {
    ///The brief as Markets' first answer.
    init(brief: MarketBrief) {
        self.init(label: "Why markets moved", title: "Why markets moved", generatedAt: brief.generatedAt,
                  answered: true, lines: brief.lines, stories: brief.stories)
    }
}
