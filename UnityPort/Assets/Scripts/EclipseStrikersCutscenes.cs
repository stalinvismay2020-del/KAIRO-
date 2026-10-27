using UnityEngine;

// Lightweight in-engine cinematic overlays and camera moves; no external assets required.
public class EclipseStrikersCutscenes : MonoBehaviour
{
    Camera cam;
    Transform hero;
    float introTime;
    float goalTime;
    bool introActive;
    bool goalActive;
    Vector3 gameplayCameraPosition;
    Quaternion gameplayCameraRotation;

    public bool IsPlaying { get { return introActive || goalActive; } }

    public void Initialize(Camera cameraRef, Transform playerRef)
    {
        cam = cameraRef;
        hero = playerRef;
        introActive = true;
        introTime = 5.2f;
        if (cam != null)
        {
            gameplayCameraPosition = cam.transform.position;
            gameplayCameraRotation = cam.transform.rotation;
        }
    }

    public void PlayGoal()
    {
        goalActive = true;
        goalTime = 2.4f;
    }

    public bool Tick(float dt)
    {
        if (cam == null || hero == null) return false;

        if (introActive)
        {
            introTime -= dt;
            float t = Mathf.Clamp01(1f - introTime / 5.2f);
            Vector3 start = hero.position + new Vector3(-9f, 6.5f, -10f);
            Vector3 end = hero.position - hero.forward * 6.5f + Vector3.up * 3.6f;
            cam.transform.position = Vector3.Lerp(start, end, Mathf.SmoothStep(0f, 1f, t));
            cam.transform.LookAt(hero.position + Vector3.up * 1.2f);
            if (introTime <= 0f)
            {
                introActive = false;
                gameplayCameraPosition = cam.transform.position;
                gameplayCameraRotation = cam.transform.rotation;
            }
            return true;
        }

        if (goalActive)
        {
            goalTime -= dt;
            Vector3 closePosition = hero.position - hero.forward * 4f + Vector3.up * 2.2f;
            cam.transform.position = Vector3.Lerp(cam.transform.position, closePosition, 5f * dt);
            cam.transform.LookAt(hero.position + Vector3.up * 1.3f);
            if (goalTime <= 0f) goalActive = false;
            return true;
        }
        return false;
    }

    void OnGUI()
    {
        float w = Screen.width;
        float h = Screen.height;
        if (introActive)
        {
            float alpha = Mathf.Clamp01(Mathf.Min((5.2f - introTime) * 2.5f, introTime * 2f));
            Color old = GUI.color;
            GUI.color = new Color(0.05f, 0.04f, 0.12f, 0.78f * alpha);
            GUI.DrawTexture(new Rect(0, h * 0.27f, w, h * 0.36f), Texture2D.whiteTexture);
            GUI.color = old;
            GUIStyle title = new GUIStyle(GUI.skin.label);
            title.alignment = TextAnchor.MiddleCenter;
            title.fontSize = Mathf.RoundToInt(Mathf.Clamp(w * 0.065f, 24, 52));
            title.fontStyle = FontStyle.Bold;
            title.normal.textColor = new Color(0.3f, 0.85f, 1f, alpha);
            GUI.Label(new Rect(0, h * 0.34f, w, h * 0.12f), "ECLIPSE STRIKERS", title);
            GUIStyle subtitle = new GUIStyle(title);
            subtitle.fontSize = Mathf.RoundToInt(Mathf.Clamp(w * 0.026f, 13, 22));
            subtitle.normal.textColor = new Color(1f, 0.25f, 0.35f, alpha);
            GUI.Label(new Rect(0, h * 0.47f, w, h * 0.08f), "AWAKEN YOUR ULTIMATE", subtitle);
        }
        else if (goalActive)
        {
            GUIStyle goal = new GUIStyle(GUI.skin.label);
            goal.alignment = TextAnchor.MiddleCenter;
            goal.fontSize = Mathf.RoundToInt(Mathf.Clamp(w * 0.085f, 34, 68));
            goal.fontStyle = FontStyle.Bold;
            goal.normal.textColor = new Color(1f, 0.22f, 0.28f, Mathf.Clamp01(goalTime * 1.5f));
            GUI.Label(new Rect(0, h * 0.18f, w, h * 0.18f), "GOOOAL!", goal);
            GUIStyle sub = new GUIStyle(goal);
            sub.fontSize = Mathf.RoundToInt(Mathf.Clamp(w * 0.03f, 15, 25));
            sub.normal.textColor = Color.white;
            GUI.Label(new Rect(0, h * 0.34f, w, h * 0.1f), "ECLIPSE FINISH", sub);
        }
    }
}
