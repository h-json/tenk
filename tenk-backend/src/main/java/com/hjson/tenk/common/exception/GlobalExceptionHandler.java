package com.hjson.tenk.common.exception;

import com.hjson.tenk.common.api.ApiResponse;
import com.hjson.tenk.common.api.ApiResponse.ApiError;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MaxUploadSizeExceededException;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiResponse<Void>> handleBusiness(BusinessException ex, HttpServletRequest req) {
        ErrorCode code = ex.getErrorCode();
        log.warn("[BusinessException] {} {} -> {} ({})", req.getMethod(), req.getRequestURI(), code.getCode(), ex.getMessage());
        return ResponseEntity.status(code.getStatus())
                .body(ApiResponse.fail(new ApiError(code.getCode(), ex.getMessage())));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiResponse<Void>> handleValidation(MethodArgumentNotValidException ex) {
        String message = ex.getBindingResult().getFieldErrors().stream()
                .findFirst()
                .map(f -> f.getField() + ": " + f.getDefaultMessage())
                .orElse(ErrorCode.INVALID_INPUT.getMessage());
        ErrorCode code = ErrorCode.INVALID_INPUT;
        return ResponseEntity.status(code.getStatus())
                .body(ApiResponse.fail(new ApiError(code.getCode(), message)));
    }

    /**
     * 요청 본문 자체를 못 읽는 경우 — 깨진 JSON, 타입 불일치, <b>enum 에 없는 코드</b> 등.
     * 핸들러가 없으면 {@code handleEtc} 로 떨어져 <b>클라이언트 잘못인데 500</b> 이 나간다.
     * 파싱 실패 원문(필드 경로·기대 타입)은 내부 정보라 노출하지 않고 로그로만 남긴다.
     */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiResponse<Void>> handleUnreadableBody(HttpMessageNotReadableException ex,
                                                                 HttpServletRequest req) {
        log.warn("[UnreadableBody] {} {} -> {}", req.getMethod(), req.getRequestURI(), ex.getMessage());
        ErrorCode code = ErrorCode.INVALID_INPUT;
        return ResponseEntity.status(code.getStatus())
                .body(ApiResponse.fail(new ApiError(code.getCode(), code.getMessage())));
    }

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    public ResponseEntity<ApiResponse<Void>> handleUploadLimit(MaxUploadSizeExceededException ex) {
        ErrorCode code = ErrorCode.MEDIA_UPLOAD_FAILED;
        return ResponseEntity.status(code.getStatus())
                .body(ApiResponse.fail(new ApiError(code.getCode(), "업로드 가능한 파일 크기를 초과했습니다.")));
    }

    @ExceptionHandler(AuthenticationException.class)
    public ResponseEntity<ApiResponse<Void>> handleAuthentication(AuthenticationException ex) {
        ErrorCode code = ErrorCode.UNAUTHORIZED;
        return ResponseEntity.status(code.getStatus())
                .body(ApiResponse.fail(new ApiError(code.getCode(), code.getMessage())));
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ApiResponse<Void>> handleAccessDenied(AccessDeniedException ex) {
        ErrorCode code = ErrorCode.FORBIDDEN;
        return ResponseEntity.status(code.getStatus())
                .body(ApiResponse.fail(new ApiError(code.getCode(), code.getMessage())));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> handleEtc(Exception ex, HttpServletRequest req) {
        log.error("[UnhandledException] {} {}", req.getMethod(), req.getRequestURI(), ex);
        ErrorCode code = ErrorCode.INTERNAL_ERROR;
        return ResponseEntity.status(code.getStatus())
                .body(ApiResponse.fail(new ApiError(code.getCode(), code.getMessage())));
    }
}
