package com.basiclab.iot.common.config;

import cn.hutool.core.util.StrUtil;
import com.basiclab.iot.common.core.util.EnvUtils;
import com.basiclab.iot.common.utils.collection.SetUtils;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.env.EnvironmentPostProcessor;
import org.springframework.core.env.ConfigurableEnvironment;

import java.util.Set;

/**
 * 多环境的 {@link EnvEnvironmentPostProcessor} 实现类
 * 将 iot.env.tag 同步到各组件的 tag 配置项（当且仅当对应项未显式配置时）。
 *
 * @author 翱翔的雄库鲁
 * @email andywebjava@163.com
 * @wechat EasyAIoT2025
 */
public class EnvEnvironmentPostProcessor implements EnvironmentPostProcessor {

    /** 预留：MQ 等组件的 tag 键可在此追加 */
    private static final Set<String> TARGET_TAG_KEYS = SetUtils.asSet();

    @Override
    public void postProcessEnvironment(ConfigurableEnvironment environment, SpringApplication application) {
        // 0. 设置 ${HOST_NAME} 兜底的环境变量
        String hostNameKey = StrUtil.subBetween(EnvUtils.HOST_NAME_VALUE, "{", "}");
        if (!environment.containsProperty(hostNameKey)) {
            environment.getSystemProperties().put(hostNameKey, EnvUtils.getHostName());
        }

        // 1.1 如果没有 iot.env.tag 配置项，则不进行配置项的修改
        String tag = EnvUtils.getTag(environment);
        if (StrUtil.isEmpty(tag)) {
            return;
        }
        // 1.2 需要修改的配置项
        for (String targetTagKey : TARGET_TAG_KEYS) {
            String targetTagValue = environment.getProperty(targetTagKey);
            if (StrUtil.isNotEmpty(targetTagValue)) {
                continue;
            }
            environment.getSystemProperties().put(targetTagKey, tag);
        }
    }

}
