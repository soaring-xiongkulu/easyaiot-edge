package com.basiclab.iot.common.web.logger.dto;

import lombok.Data;

import java.time.LocalDateTime;

/**
 * API 异常日志构建 DTO（原 infra 模块 API 契约的本地替代，仅用于全局异常处理中的结构化日志）。
 */
@Data
public class ApiErrorLogCreateReqDTO {

    private Long userId;
    private Integer userType;
    private String exceptionName;
    private String exceptionMessage;
    private String exceptionRootCauseMessage;
    private String exceptionStackTrace;
    private String exceptionClassName;
    private String exceptionFileName;
    private String exceptionMethodName;
    private Integer exceptionLineNumber;
    private String traceId;
    private String applicationName;
    private String requestUrl;
    private String requestParams;
    private String requestMethod;
    private String userAgent;
    private String userIp;
    private LocalDateTime exceptionTime;
}
