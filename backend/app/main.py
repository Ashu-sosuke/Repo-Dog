from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import auth, dashboard, projects, sync

app = FastAPI(
    title="Repo Dog Backend API",
    description="FastAPI service for GitHub sync, Supabase data management, and Firebase token verification.",
    version="1.0.0"
)

# Allowed origins: any localhost port (Flutter Web dev server),
# plus common Flutter web ports. The wildcard "*" doesn't work
# with allow_credentials=True, so we enumerate localhost origins explicitly.
ALLOWED_ORIGINS = [
    "http://localhost",
    "http://localhost:3000",
    "http://localhost:4040",
    "http://localhost:5000",
    "http://localhost:5173",
    "http://localhost:7357",
    "http://localhost:8080",
    "http://localhost:9000",
    "http://127.0.0.1",
    "http://127.0.0.1:3000",
    "http://127.0.0.1:5000",
    "http://127.0.0.1:8080",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",  # matches ANY localhost port
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API Routers
app.include_router(auth.router)
app.include_router(dashboard.router)
app.include_router(projects.router)
app.include_router(sync.router)

@app.get("/")
async def root():
    return {
        "app": "Repo Dog API",
        "status": "healthy",
        "version": "1.0.0"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
