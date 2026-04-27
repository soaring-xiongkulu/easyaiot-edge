package com.basiclab.iot.common.config;

import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;

@AutoConfiguration
@ConditionalOnProperty(prefix = "iot.tenant", value = "enable", matchIfMissing = true) // 允许使用 iot.tenant.enable=false 禁用多租户
public class YudaoTenantRpcAutoConfiguration {
}
