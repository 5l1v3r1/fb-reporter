part of oauth2_v2_api_browser;

/**
 * Base class for all Browser API clients, offering generic methods for HTTP Requests to the API
 */
abstract class BrowserClient extends Client {

  final oauth.OAuth2 _auth;
  core.bool _jsClientLoaded = false;

  BrowserClient([oauth.OAuth2 this._auth]) : super();

  /**
   * Loads the JS Client Library to make CORS-Requests
   */
  async.Future<core.bool> _loadJsClient() {
    var completer = new async.Completer();

    if (_jsClientLoaded) {
      completer.complete(true);
      return completer.future;
    }

    js.scoped((){
      js.context["handleClientLoad"] =  new js.Callback.once(() {
        _jsClientLoaded = true;
        completer.complete(true);
      });
    });

    html.ScriptElement script = new html.ScriptElement();
    script.src = "http://apis.google.com/js/client.js?onload=handleClientLoad";
    script.type = "text/javascript";
    html.document.body.children.add(script);

    return completer.future;
  }

  /**
   * Makes a request via the JS Client Library to circumvent CORS-problems
   */
  async.Future _makeJsClientRequest(core.String requestUrl, core.String method, {core.String body, core.String contentType, core.Map queryParams}) {
    var completer = new async.Completer();
    var requestData = new core.Map();
    requestData["path"] = requestUrl;
    requestData["method"] = method;
    requestData["headers"] = new core.Map();

    if (queryParams != null) {
      requestData["params"] = queryParams;
    }

    if (body != null) {
      requestData["body"] = body;
      requestData["headers"]["Content-Type"] = contentType;
    }
    if (makeAuthRequests && _auth != null && _auth.token != null) {
      requestData["headers"]["Authorization"] = "${_auth.token.type} ${_auth.token.data}";
    }

    js.scoped(() {
      var request = js.context["gapi"]["client"]["request"](js.map(requestData));
      var callback = new js.Callback.once((jsonResp, rawResp) {
        if (jsonResp == null || (jsonResp is core.bool && jsonResp == false)) {
          var raw = JSON.parse(rawResp);
          if (raw["gapiRequest"]["data"]["status"] >= 400) {
            completer.completeError(new APIRequestException("JS Client - ${raw["gapiRequest"]["data"]["status"]} ${raw["gapiRequest"]["data"]["statusText"]} - ${raw["gapiRequest"]["data"]["body"]}"));
          } else {
            completer.complete({});
          }
        } else {
          completer.complete(js.context["JSON"]["stringify"](jsonResp));
        }
      });
      request.execute(callback);
    });

    return completer.future;
  }

  /**
   * Sends a HTTPRequest using [method] (usually GET or POST) to [requestUrl] using the specified [urlParams] and [queryParams]. Optionally include a [body] in the request.
   */
  async.Future request(core.String requestUrl, core.String method, {core.String body, core.String contentType:"application/json", core.Map urlParams, core.Map queryParams}) {
    var request = new html.HttpRequest();
    var completer = new async.Completer();

    if (urlParams == null) urlParams = {};
    if (queryParams == null) queryParams = {};

    params.forEach((key, param) {
      if (param != null && queryParams[key] == null) {
        queryParams[key] = param;
      }
    });

    var path;
    if (requestUrl.substring(0,1) == "/") {
      path ="$rootUrl${requestUrl.substring(1)}";
    } else {
      path ="$rootUrl${basePath.substring(1)}$requestUrl";
    }
    var url = new oauth.UrlPattern(path).generate(urlParams, queryParams);

    void handleError() {
      if (request.status == 0) {
        _loadJsClient().then((v) {
          if (requestUrl.substring(0,1) == "/") {
            path = requestUrl;
          } else {
            path ="$basePath$requestUrl";
          }
          url = new oauth.UrlPattern(path).generate(urlParams, {});
          _makeJsClientRequest(url, method, body: body, contentType: contentType, queryParams: queryParams)
            .then((response) {
              var data = JSON.parse(response);
              completer.complete(data);
            })
            .catchError((e) {
              completer.completeError(e);
              return true;
            });
        });
      } else {
        var error = "";
        if (request.responseText != null) {
          var errorJson;
          try {
            errorJson = JSON.parse(request.responseText);
          } on core.FormatException {
            errorJson = null;
          }
          if (errorJson != null && errorJson.containsKey("error")) {
            error = "${errorJson["error"]["code"]} ${errorJson["error"]["message"]}";
          }
        }
        if (error == "") {
          error = "${request.status} ${request.statusText}";
        }
        completer.completeError(new APIRequestException(error));
      }
    }

    request.onLoad.listen((_) {
      if (request.status > 0 && request.status < 400) {
        var data = {};
        if (!request.responseText.isEmpty) {
          data = JSON.parse(request.responseText);
        }
        completer.complete(data);
      } else {
        handleError();
      }
    });

    request.onError.listen((_) => handleError());

    request.open(method, url);
    request.setRequestHeader("Content-Type", contentType);
    if (makeAuthRequests && _auth != null) {
      _auth.authenticate(request).then((request) => request.send(body));
    } else {
      request.send(body);
    }

    return completer.future;
  }
}

