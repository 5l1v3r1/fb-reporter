part of oauth2_v2_api_client;

/**
 * Base class for all API clients, offering generic methods for HTTP Requests to the API
 */
abstract class Client {
  core.String basePath;
  core.String rootUrl;
  core.bool makeAuthRequests;
  core.Map params;

  static const _boundary = "-------314159265358979323846";
  static const _delimiter = "\r\n--$_boundary\r\n";
  static const _closeDelim = "\r\n--$_boundary--";

  Client() {
    params = new core.Map();
    makeAuthRequests = false;
  }

  /**
   * Sends a HTTPRequest using [method] (usually GET or POST) to [requestUrl] using the specified [urlParams] and [queryParams]. Optionally include a [body] in the request.
   */
  async.Future request(core.String requestUrl, core.String method, {core.String body, core.String contentType:"application/json", core.Map urlParams, core.Map queryParams});

  /**
   * Joins [content] (encoded as Base64-String) with specified [contentType] and additional request [body] into one multipart-body and send a HTTPRequest with [method] (usually POST) to [requestUrl]
   */
  async.Future upload(core.String requestUrl, core.String method, core.String body, core.String content, core.String contentType, {core.Map urlParams, core.Map queryParams}) {
    var multiPartBody = new core.StringBuffer();
    if (contentType == null || contentType.isEmpty) {
      contentType = "application/octet-stream";
    }
    multiPartBody
    ..write(_delimiter)
    ..write("Content-Type: application/json\r\n\r\n")
    ..write(body)
    ..write(_delimiter)
    ..write("Content-Type: ")
    ..write(contentType)
    ..write("\r\n")
    ..write("Content-Transfer-Encoding: base64\r\n")
    ..write("\r\n")
    ..write(content)
    ..write(_closeDelim);

    return request(requestUrl, method, body: multiPartBody.toString(), contentType: "multipart/mixed; boundary=\"$_boundary\"", urlParams: urlParams, queryParams: queryParams);
  }
}

/// Base-class for all API Resources
abstract class Resource {
  /// The [Client] to be used for all requests
  final Client _client;

  /// Create a new Resource, using the specified [Client] for requests
  Resource(Client this._client);
}

/// Exception thrown when the HTTP Request to the API failed
class APIRequestException implements core.Exception {
  final core.String msg;
  const APIRequestException([this.msg]);
  core.String toString() => (msg == null) ? "APIRequestException" : "APIRequestException: $msg";
}

