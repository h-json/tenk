package com.hjson.tenk.domain.app;

import com.hjson.tenk.common.api.ApiResponse;
import com.hjson.tenk.domain.app.dto.AppVersionResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "App", description = "앱 메타/버전 API")
@RestController
@RequestMapping("/api/app")
@RequiredArgsConstructor
public class AppVersionController {

    private final AppVersionService appVersionService;

    @Operation(summary = "앱 버전 상태 조회",
            description = "클라 현재 버전을 서버 정책(최소/최신)과 비교해 최신/권장/강제 상태를 돌려준다. "
                    + "인증 불필요(부팅 게이트에서 호출). currentVersion 이 없거나 이상하면 게이트를 걸지 않는다(fail-open).")
    @GetMapping("/version")
    public ApiResponse<AppVersionResponse> version(
            @RequestParam(name = "platform", required = false) String platform,
            @RequestParam(name = "currentVersion", required = false) String currentVersion) {
        return ApiResponse.ok(appVersionService.resolve(platform, currentVersion));
    }
}
