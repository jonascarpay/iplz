import falcon
import falcon.asgi

class Server:
    async def on_get(self, req, res):
        res.status = falcon.HTTP_200
        res.content_type = falcon.MEDIA_TEXT
        res.text = req.remote_addr + "\n"


app = falcon.asgi.App()
app.add_route("/", Server())
