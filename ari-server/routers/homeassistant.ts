import { router } from "../system/router.js";
import { saveHACredentials, getHACredentials } from "../tools/homeassistant.js";
import axios from "axios";
import { logger } from "../infra/logger.js";

router.on("/GET_HA_CREDENTIALS", async (ctx, params) => {
  logger.info(`[HA] Requesting credentials from ${ctx.uuid}`);
  try {
    const creds = await getHACredentials();
    ctx.send("/GET_HA_CREDENTIALS", {
      ok: true,
      data: creds,
    });
  } catch (error: any) {
    logger.error(`[HA] Failed to get credentials: ${error.message}`);
    ctx.send("/GET_HA_CREDENTIALS", {
      ok: false,
      error: error.message,
    });
  }
});

router.on("/GET_HA_DEVICES", async (ctx, params) => {
  logger.info(`[HA] Fetching devices for ${ctx.uuid}`);
  try {
    const creds = await getHACredentials();
    const response = await axios.get(`${creds.url}/api/states`, {
      headers: { Authorization: `Bearer ${creds.token}` },
      timeout: 5000,
    });

    const entities = response.data as any[];
    const devices = entities
      .filter(
        (e) =>
          e.entity_id.startsWith("light.") ||
          e.entity_id.startsWith("switch.") ||
          e.entity_id.startsWith("climate.") ||
          e.entity_id.startsWith("fan.") ||
          e.entity_id.startsWith("cover.") ||
          e.entity_id.startsWith("media_player."),
      )
      .map((e) => ({
        id: e.entity_id,
        name: e.attributes.friendly_name || e.entity_id,
        state: e.state,
        type: e.entity_id.split(".")[0],
      }));

    logger.info(`[HA] Found ${devices.length} devices`);
    ctx.send("/GET_HA_DEVICES", {
      ok: true,
      data: { devices },
    });
  } catch (error: any) {
    logger.error(`[HA] Failed to get devices: ${error.message}`);
    ctx.send("/GET_HA_DEVICES", {
      ok: false,
      error: error.message,
    });
  }
});

router.on("/SET_HA_CREDENTIALS", async (ctx, params) => {
  const { url, token } = params as { url: string; token: string };
  logger.info(`[HA] Setting new credentials for ${ctx.uuid}: ${url}`);

  if (!url || !token) {
    logger.warn(`[HA] Missing URL or Token in set credentials request`);
    return ctx.send("/SET_HA_CREDENTIALS", {
      ok: false,
      error: "URL and Token are required",
    });
  }

  try {
    const sanitizedUrl = url.endsWith("/") ? url.slice(0, -1) : url;

    // 1. Verify connection first
    try {
      await axios.get(`${sanitizedUrl}/api/config`, {
        headers: { Authorization: `Bearer ${token}` },
        timeout: 5000,
      });
      logger.info(`[HA] Connection verified for ${sanitizedUrl}`);
    } catch (netErr: any) {
      logger.error(`[HA] Connection verification failed: ${netErr.message}`);
      return ctx.send("/SET_HA_CREDENTIALS", {
        ok: false,
        error: `서버 연결 실패: ${netErr.message}. URL과 토큰을 확인해 주세요.`,
      });
    }

    // 2. Save to keychain
    await saveHACredentials(sanitizedUrl, token);
    logger.info(`[HA] Credentials saved successfully`);

    ctx.send("/SET_HA_CREDENTIALS", {
      ok: true,
      data: { success: true },
    });
  } catch (error: any) {
    logger.error(`[HA] Error during credentials save: ${error.message}`);
    ctx.send("/SET_HA_CREDENTIALS", {
      ok: false,
      error: `오류 발생: ${error.message}`,
    });
  }
});

router.on("/CONTROL_HA_DEVICE", async (ctx, params) => {
  const { entity_id, service, domain = "homeassistant" } = params as {
    entity_id: string;
    service: string;
    domain?: string;
  };
  logger.info(`[HA] Control: ${domain}.${service} -> ${entity_id}`);

  if (!entity_id || !service) {
    logger.warn(`[HA] Missing entity_id or service in control request`);
    return ctx.send("/CONTROL_HA_DEVICE", {
      ok: false,
      error: "entity_id and service are required",
    });
  }

  try {
    const creds = await getHACredentials();
    const payload = { entity_id };

    await axios.post(
      `${creds.url}/api/services/${domain}/${service}`,
      payload,
      { headers: { Authorization: `Bearer ${creds.token}` } }
    );

    logger.info(`[HA] ${domain}.${service} successful on ${entity_id}`);
    ctx.send("/CONTROL_HA_DEVICE", {
      ok: true,
      data: { success: true },
    });
  } catch (error: any) {
    logger.error(`[HA] Control failed for ${entity_id}: ${error.message}`);
    ctx.send("/CONTROL_HA_DEVICE", {
      ok: false,
      error: error.message,
    });
  }
});
