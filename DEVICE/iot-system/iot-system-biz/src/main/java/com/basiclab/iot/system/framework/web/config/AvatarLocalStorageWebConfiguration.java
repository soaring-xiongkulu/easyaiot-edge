package com.basiclab.iot.system.framework.web.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * 头像本地存储目录映射为 HTTP 静态路径（替代原 infra 文件服务）。
 */
@Configuration(proxyBeanMethods = false)
public class AvatarLocalStorageWebConfiguration implements WebMvcConfigurer {

    @Value("${sys.file.avatar-dir:${user.home}/iot-file/avatar}")
    private String avatarDir;

    @Value("${sys.file.avatar-url-prefix:/static-avatar/}")
    private String avatarUrlPrefix;

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        Path dir = Paths.get(avatarDir).toAbsolutePath().normalize();
        String location = dir.toUri().toString();
        if (!location.endsWith("/")) {
            location = location + "/";
        }
        String pattern = avatarUrlPrefix.startsWith("/") ? avatarUrlPrefix : "/" + avatarUrlPrefix;
        if (!pattern.endsWith("/")) {
            pattern = pattern + "/";
        }
        registry.addResourceHandler(pattern + "**").addResourceLocations(location);
    }
}
