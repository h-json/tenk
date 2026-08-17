package com.hjson.tenk.common.exception;

import com.hjson.tenk.common.api.ApiResponse;
import com.hjson.tenk.common.api.ApiResponse.ApiError;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.multipart.support.MissingServletRequestPartException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

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
     *
     * <p>⚠️ <b>{@code ex.getMessage()} 를 찍지 말 것.</b> Jackson 의 파싱 실패 메시지에는
     * 문제가 된 <b>요청 본문 조각이 그대로 들어간다</b>({@code from String "홍길동"} 형태) —
     * 닉네임·문의 본문·회신 이메일이 로그로 새는 경로다. 예외 종류만으로 원인은 충분히 좁혀진다.
     */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiResponse<Void>> handleUnreadableBody(HttpMessageNotReadableException ex,
                                                                 HttpServletRequest req) {
        log.warn("[UnreadableBody] {} {} -> {}", req.getMethod(), req.getRequestURI(),
                ex.getClass().getSimpleName());
        ErrorCode code = ErrorCode.INVALID_INPUT;
        return ResponseEntity.status(code.getStatus())
                .body(ApiResponse.fail(new ApiError(code.getCode(), code.getMessage())));
    }

    /**
     * 디스패치 단계에서 걸러지는 <b>잘못된 호출</b> 모음 — 경로 변수 타입 불일치, multipart part 누락,
     * 필수 쿼리 파라미터 누락, 없는 경로, 안 맞는 메서드·Content-Type.
     *
     * <p>핸들러가 없으면 전부 {@code handleEtc} 로 떨어져 <b>클라이언트 잘못인데 500</b> 이 나가고,
     * 진짜 서버 장애와 섞여 로그·모니터링이 오염된다 ({@code handleUnreadableBody} 와 같은 갈래).
     *
     * <p>⚠️ 로그에는 <b>예외 종류만</b> 남긴다 — 실패 원문에 파라미터 값이 실릴 수 있다
     * ({@code handleUnreadableBody} 와 같은 이유).
     */
    @ExceptionHandler({
            MethodArgumentTypeMismatchException.class,
            MissingServletRequestParameterException.class,
            MissingServletRequestPartException.class,
            NoResourceFoundException.class,
            HttpRequestMethodNotSupportedException.class,
            HttpMediaTypeNotSupportedException.class,
    })
    public ResponseEntity<ApiResponse<Void>> handleMalformedRequest(Exception ex, HttpServletRequest req) {
        ErrorCode code = switch (ex) {
            case NoResourceFoundException ignored -> ErrorCode.NOT_FOUND;
            case HttpRequestMethodNotSupportedException ignored -> ErrorCode.METHOD_NOT_ALLOWED;
            case HttpMediaTypeNotSupportedException ignored -> ErrorCode.UNSUPPORTED_MEDIA_TYPE;
            default -> ErrorCode.INVALID_INPUT;
        };
        log.warn("[MalformedRequest] {} {} -> {} ({})",
                req.getMethod(), req.getRequestURI(), code.getCode(), ex.getClass().getSimpleName());
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
