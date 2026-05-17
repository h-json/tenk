package com.hjson.manwon.domain.challenge.event;

import com.hjson.manwon.domain.challenge.ChallengeResult;

public record ChallengeFinishedEvent(Long challengeId, Long userId, ChallengeResult result) {
}
