/**
 * Cloudflare Worker - Uptime Kuma 状态页面反向代理
 *
 * 用于将自定义域名的请求转发到 Choreo 平台上的 Uptime Kuma 服务
 */

// 配置：你的 Choreo 服务域名（不带 https://）
const CHOREO_HOST = 'your-app.choreo.dev';

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const originalHost = url.hostname;

    // 构建目标 URL
    const targetUrl = new URL(url.pathname + url.search, `https://${CHOREO_HOST}`);

    // 复制原始请求头
    const headers = new Headers(request.headers);

    // 设置必要的转发头
    headers.set('X-Forwarded-Host', originalHost);
    headers.set('X-Forwarded-Proto', 'https');
    headers.set('X-Real-IP', request.headers.get('CF-Connecting-IP') || '');

    // 设置 Host 头为目标主机
    headers.set('Host', CHOREO_HOST);

    // 处理 WebSocket 升级请求
    if (request.headers.get('Upgrade') === 'websocket') {
      return handleWebSocket(request, targetUrl, headers);
    }

    // 创建新请求
    const newRequest = new Request(targetUrl.toString(), {
      method: request.method,
      headers: headers,
      body: request.body,
      redirect: 'manual', // 手动处理重定向
    });

    try {
      let response = await fetch(newRequest);

      // 处理重定向：将目标域名替换为原始域名
      if (response.status >= 300 && response.status < 400) {
        const location = response.headers.get('Location');
        if (location) {
          const newLocation = location.replace(
            new RegExp(`https?://${CHOREO_HOST}`, 'g'),
            `https://${originalHost}`
          );
          const newHeaders = new Headers(response.headers);
          newHeaders.set('Location', newLocation);
          return new Response(response.body, {
            status: response.status,
            statusText: response.statusText,
            headers: newHeaders,
          });
        }
      }

      // 处理 HTML 响应：替换内容中的域名引用
      const contentType = response.headers.get('Content-Type') || '';
      if (contentType.includes('text/html')) {
        let body = await response.text();

        // 替换 HTML 中的 Choreo 域名为自定义域名
        body = body.replace(
          new RegExp(CHOREO_HOST, 'g'),
          originalHost
        );

        const newHeaders = new Headers(response.headers);
        newHeaders.delete('Content-Length'); // 内容长度可能已改变

        return new Response(body, {
          status: response.status,
          statusText: response.statusText,
          headers: newHeaders,
        });
      }

      return response;

    } catch (error) {
      return new Response(`Proxy Error: ${error.message}`, {
        status: 502,
        headers: { 'Content-Type': 'text/plain' },
      });
    }
  },
};

/**
 * 处理 WebSocket 连接
 */
async function handleWebSocket(request, targetUrl, headers) {
  // Cloudflare Workers 对 WebSocket 的支持
  const wsUrl = targetUrl.toString().replace('https://', 'wss://');

  const upgradeHeader = request.headers.get('Upgrade');
  if (!upgradeHeader || upgradeHeader !== 'websocket') {
    return new Response('Expected WebSocket', { status: 426 });
  }

  // 转发 WebSocket 请求
  const response = await fetch(wsUrl, {
    headers: headers,
  });

  return response;
}
