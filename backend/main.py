from firebase_functions import https_fn
from firebase_admin import initialize_app
from server.main import app as fastapi_app

initialize_app()

@https_fn.on_request()
def api(req: https_fn.Request) -> https_fn.Response:
    return https_fn.Response.from_flask(fastapi_app)
