# openapi.api.DefaultApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://jsonplaceholder.typicode.com*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getPostById**](DefaultApi.md#getpostbyid) | **GET** /posts/{id} | Get a single post
[**getPosts**](DefaultApi.md#getposts) | **GET** /posts | Get all posts


# **getPostById**
> Post getPostById(id)

Get a single post

### Example
```dart
import 'package:openapi/api.dart';

final api = Openapi().getDefaultApi();
final int id = 56; // int | 

try {
    final response = api.getPostById(id);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getPostById: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **int**|  | 

### Return type

[**Post**](Post.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getPosts**
> BuiltList<Post> getPosts()

Get all posts

### Example
```dart
import 'package:openapi/api.dart';

final api = Openapi().getDefaultApi();

try {
    final response = api.getPosts();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getPosts: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**BuiltList&lt;Post&gt;**](Post.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

