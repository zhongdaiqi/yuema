import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HuaweiAuthAgreementPage extends StatelessWidget {
  const HuaweiAuthAgreementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('华为账号用户认证协议'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: WebViewWidget(
        controller: WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (int progress) {
                // 加载进度更新
              },
              onPageStarted: (String url) {
                // 页面开始加载
              },
              onPageFinished: (String url) {
                // 页面加载完成
              },
              onWebResourceError: (WebResourceError error) {
                // 加载错误处理
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('加载页面失败: ${error.description}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          )
          ..loadRequest(Uri.parse('https://privacy.consumer.huawei.com/legal/id/authentication-terms.htm?code=CN&language=zh-CN')),
      ),
    );
  }
}