# openapi.api.DefaultApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://api.github.com*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getAuthenticatedUser**](DefaultApi.md#getauthenticateduser) | **GET** /user | Get the authenticated user
[**listRepos**](DefaultApi.md#listrepos) | **GET** /user/repos | List repositories for the authenticated user


# **getAuthenticatedUser**
> PrivateUser getAuthenticatedUser()

Get the authenticated user

### Example
```dart
import 'package:openapi/api.dart';

final api = Openapi().getDefaultApi();

try {
    final response = api.getAuthenticatedUser();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getAuthenticatedUser: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**PrivateUser**](PrivateUser.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listRepos**
> BuiltList<Repository> listRepos(sort, direction)

List repositories for the authenticated user

### Example
```dart
import 'package:openapi/api.dart';

final api = Openapi().getDefaultApi();
final String sort = sort_example; // String | Property to sort repositories by
final String direction = direction_example; // String | Sort order

try {
    final response = api.listRepos(sort, direction);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listRepos: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sort** | **String**| Property to sort repositories by | [optional] [default to 'full_name']
 **direction** | **String**| Sort order | [optional] 

### Return type

[**BuiltList&lt;Repository&gt;**](Repository.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

