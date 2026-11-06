class CorsMiddleware:
    """LAN ichidagi Flutter web ilovasi uchun CORS.

    API'ga boshqa origin (masalan http://10.144.82.22:8080) dan
    so'rovlar ruxsat etiladi.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.method == 'OPTIONS':
            from django.http import HttpResponse
            response = HttpResponse(status=200)
        else:
            response = self.get_response(request)
        response['Access-Control-Allow-Origin'] = '*'
        response['Access-Control-Allow-Methods'] = 'GET, POST, PUT, PATCH, DELETE, OPTIONS'
        response['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
        return response
