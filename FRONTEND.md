# Writing to the backend from a frontend

Send a `POST` request with a JSON body to the backend URL. That's it.

## fetch (modern browsers)

```js
await fetch("https://your.domain.com/", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ hello: "world" }),
});
```

## With error handling

```js
async function send(data) {
  const res = await fetch("https://your.domain.com/", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  });

  if (!res.ok) throw new Error(`Server returned ${res.status}`);
  return res.json(); // { file: "20240415T120000000000_abc123.json" }
}
```

## Minimal HTML form example

Submits form data as JSON on button click — no framework needed.

```html
<form id="form">
  <input name="name" placeholder="Name" required />
  <input name="email" type="email" placeholder="Email" required />
  <button type="submit">Send</button>
</form>

<script>
  document.getElementById("form").addEventListener("submit", async (e) => {
    e.preventDefault();
    const data = Object.fromEntries(new FormData(e.target));
    await fetch("https://your.domain.com/", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(data),
    });
  });
</script>
```

## CORS

If your frontend is served from a different origin than the backend, the browser will block the request. Add CORS headers in `main.py`:

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://your-frontend.com"],  # or ["*"] to allow all
    allow_methods=["POST"],
)
```

Then reinstall and restart:

```bash
sudo bash /opt/generic-backend/scripts/update.sh
```
