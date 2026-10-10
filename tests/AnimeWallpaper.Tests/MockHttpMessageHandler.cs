using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

namespace AnimeWallpaper.Tests;

public class MockHttpMessageHandler : HttpMessageHandler
{
    private readonly Func<HttpRequestMessage, HttpResponseMessage> _responseHandler;
    public List<HttpRequestMessage> SentRequests { get; } = new();

    public MockHttpMessageHandler(Func<HttpRequestMessage, HttpResponseMessage> responseHandler)
    {
        _responseHandler = responseHandler;
    }

    public static MockHttpMessageHandler WithJsonResponse(string json, HttpStatusCode statusCode = HttpStatusCode.OK)
    {
        return new MockHttpMessageHandler(_ => new HttpResponseMessage(statusCode)
        {
            Content = new StringContent(json, System.Text.Encoding.UTF8, "application/json")
        });
    }

    public static MockHttpMessageHandler WithStatusCode(HttpStatusCode statusCode)
    {
        return new MockHttpMessageHandler(_ => new HttpResponseMessage(statusCode));
    }

    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        SentRequests.Add(request);
        return Task.FromResult(_responseHandler(request));
    }
}
