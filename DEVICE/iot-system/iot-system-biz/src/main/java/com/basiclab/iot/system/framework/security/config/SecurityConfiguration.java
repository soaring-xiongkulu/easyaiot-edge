package com.basiclab.iot.system.framework.security.config;

import com.basiclab.iot.common.config.AuthorizeRequestsCustomizer;
import com.basiclab.iot.system.enums.ApiConstants;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.ExpressionUrlAuthorizationConfigurer;

/**
 * SecurityConfiguration
 *
 * @author 翱翔的雄库鲁
 * @email andywebjava@163.com
 * @wechat EasyAIoT2025
 */
@Configuration(proxyBeanMethods = false, value = "systemSecurityConfiguration")
public class SecurityConfiguration {

    @Value("${sys.file.avatar-url-prefix:/static-avatar/}")
    private String avatarUrlPrefix;

    @Bean("systemAuthorizeRequestsCustomizer")
    public AuthorizeRequestsCustomizer authorizeRequestsCustomizer() {
        String avatarPattern = normalizeAvatarUrlPrefix(avatarUrlPrefix) + "**";
        return new AuthorizeRequestsCustomizer() {

            @Override
            public void customize(ExpressionUrlAuthorizationConfigurer<HttpSecurity>.ExpressionInterceptUrlRegistry registry) {
                // TODO BasicLab：这个每个项目都需要重复配置，得捉摸有没通用的方案
                // Swagger 接口文档
                registry.antMatchers("/v3/api-docs/**").permitAll() // 元数据
                        .antMatchers("/swagger-ui.html").permitAll(); // Swagger UI
                // Druid 监控
                registry.antMatchers("/druid/**").anonymous();
                // Spring Boot Actuator 的安全配置
                registry.antMatchers("/actuator").anonymous()
                        .antMatchers("/actuator/**").anonymous();
                // RPC 服务的安全配置
                registry.antMatchers(ApiConstants.PREFIX + "/**").permitAll();
                // 本地头像静态资源（无 infra 文件服务时，与 sys.file.avatar-url-prefix 一致）
                registry.antMatchers(avatarPattern).permitAll();
            }

        };
    }

    private static String normalizeAvatarUrlPrefix(String prefix) {
        String p = prefix.startsWith("/") ? prefix : "/" + prefix;
        return p.endsWith("/") ? p : p + "/";
    }

}
