using System.Collections.Generic;
using UnityEngine;

// Runtime-generated prototype: pitch, 4v4 players, ball, goals, camera and touch HUD.
// Original placeholder geometry is used so the project needs no third-party assets.
public class EclipseStrikersGame : MonoBehaviour
{
    const float MatchLength = 300f;
    readonly List<PlayerAgent> players = new List<PlayerAgent>();
    GameObject ball;
    Rigidbody ballBody;
    Transform userPlayer;
    Camera gameCamera;
    EclipseStrikersCutscenes cutscenes;
    float timeLeft = MatchLength;
    int blueScore, redScore;
    bool matchEnded;
    float abilityReadyAt;
    Vector2 moveInput;
    bool shootPressed, passPressed, sprintHeld, abilityPressed;
    GUIStyle titleStyle, buttonStyle, scoreStyle;

    class PlayerAgent
    {
        public Transform transform;
        public int team;
        public bool user;
        public float speed;
        public float thinkOffset;
    }

    void Start()
    {
        Application.targetFrameRate = 60;
        BuildPitch();
        BuildGoals();
        BuildBall();
        BuildPlayers();
        BuildCamera();
        BuildLighting();
        cutscenes = gameObject.AddComponent<EclipseStrikersCutscenes>();
        cutscenes.Initialize(gameCamera, userPlayer);
    }

    void Update()
    {
        if (matchEnded) return;
        if (cutscenes != null && cutscenes.Tick(Time.deltaTime)) return;
        timeLeft -= Time.deltaTime;
        if (timeLeft <= 0f) { timeLeft = 0f; matchEnded = true; }

        UpdateUser();
        UpdateAI();
        UpdateCamera();

        if (shootPressed) KickBall(13f, 0.6f);
        if (passPressed) PassBall();
        if (abilityPressed && Time.time >= abilityReadyAt) UseUltimate();
        shootPressed = passPressed = abilityPressed = false;

        CheckGoal();
    }

    void BuildPitch()
    {
        CreateCube("Pitch", new Vector3(0, -0.25f, 0), new Vector3(24, 0.5f, 38), new Color(0.12f, 0.48f, 0.24f));
        for (int i = -2; i <= 2; i++)
            CreateCube("Pitch stripe", new Vector3(0, 0.012f, i * 6.3f), new Vector3(23.8f, 0.02f, 3.1f), i % 2 == 0 ? new Color(0.14f,0.53f,0.27f) : new Color(0.11f,0.44f,0.21f));
        // White markings are raised slightly to avoid z-fighting.
        Line("Touchline left", new Vector3(-11.4f,0.04f,-18), new Vector3(-11.4f,0.04f,18), 0.08f);
        Line("Touchline right", new Vector3(11.4f,0.04f,-18), new Vector3(11.4f,0.04f,18), 0.08f);
        Line("Goal line north", new Vector3(-11.4f,0.04f,18), new Vector3(11.4f,0.04f,18), 0.08f);
        Line("Goal line south", new Vector3(-11.4f,0.04f,-18), new Vector3(11.4f,0.04f,-18), 0.08f);
        Line("Halfway line", new Vector3(-11.4f,0.04f,0), new Vector3(11.4f,0.04f,0), 0.06f);
        GameObject ring = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        ring.name = "Centre circle";
        ring.transform.position = new Vector3(0,0.03f,0);
        ring.transform.localScale = new Vector3(5,0.025f,5);
        SetColor(ring, Color.white);
        Collider c = ring.GetComponent<Collider>(); if (c) Destroy(c);
        CreateCube("North boundary", new Vector3(0,0.6f,19.3f), new Vector3(26,1.2f,0.3f), Color.gray);
        CreateCube("South boundary", new Vector3(0,0.6f,-19.3f), new Vector3(26,1.2f,0.3f), Color.gray);
    }

    void BuildGoals()
    {
        for (int side = -1; side <= 1; side += 2)
        {
            float z = side * 18.3f;
            Color postColor = Color.white;
            CreateCube("Goal left post", new Vector3(-3,1,z), new Vector3(0.18f,2,0.18f), postColor);
            CreateCube("Goal right post", new Vector3(3,1,z), new Vector3(0.18f,2,0.18f), postColor);
            CreateCube("Goal crossbar", new Vector3(0,2,z), new Vector3(6,0.18f,0.18f), postColor);
        }
    }

    void BuildBall()
    {
        ball = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        ball.name = "Football";
        ball.transform.position = new Vector3(0,0.55f,0);
        ball.transform.localScale = Vector3.one * 0.62f;
        SetColor(ball, Color.white);
        ballBody = ball.AddComponent<Rigidbody>();
        ballBody.mass = 0.43f;
        ballBody.drag = 0.18f;
        ballBody.angularDrag = 0.08f;
        ballBody.collisionDetectionMode = CollisionDetectionMode.ContinuousDynamic;
        ballBody.interpolation = RigidbodyInterpolation.Interpolate;
        PhysicMaterial mat = new PhysicMaterial("Football bounce") { bounciness = 0.48f, dynamicFriction = 0.45f, staticFriction = 0.5f };
        ball.GetComponent<Collider>().material = mat;
    }

    void BuildPlayers()
    {
        // Team 0 attacks toward +Z; team 1 attacks toward -Z.
        Vector3[] formation = {
            new Vector3(0,0,-7), new Vector3(-5,0,-3), new Vector3(5,0,-3), new Vector3(0,0,1)
        };
        for (int team = 0; team < 2; team++)
        {
            for (int i = 0; i < 4; i++)
            {
                Vector3 p = formation[i];
                p.z *= team == 0 ? 1 : -1;
                if (team == 0 && i == 0) p = new Vector3(0,0,-8);
                GameObject model = CreatePlayerModel(team == 0 ? new Color(0.08f,0.45f,1f) : new Color(0.95f,0.13f,0.2f));
                model.name = (team == 0 ? "Blue" : "Red") + " Player " + (i + 1);
                model.transform.position = p;
                PlayerAgent agent = new PlayerAgent { transform = model.transform, team = team, user = team == 0 && i == 0, speed = 5.1f, thinkOffset = i * 0.7f };
                players.Add(agent);
                if (agent.user) userPlayer = model.transform;
            }
        }
    }

    GameObject CreatePlayerModel(Color jersey)
    {
        GameObject root = new GameObject("Footballer");
        GameObject body = GameObject.CreatePrimitive(PrimitiveType.Capsule);
        body.transform.SetParent(root.transform, false);
        body.transform.localPosition = new Vector3(0,0.9f,0);
        body.transform.localScale = new Vector3(0.72f,0.9f,0.72f);
        SetColor(body, jersey);
        GameObject head = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        head.transform.SetParent(root.transform, false);
        head.transform.localPosition = new Vector3(0,1.85f,0);
        head.transform.localScale = new Vector3(0.62f,0.62f,0.62f);
        SetColor(head, new Color(1f,0.77f,0.6f));
        GameObject hair = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        hair.transform.SetParent(root.transform, false);
        hair.transform.localPosition = new Vector3(0,2.06f,-0.04f);
        hair.transform.localScale = new Vector3(0.65f,0.35f,0.65f);
        SetColor(hair, new Color(0.08f,0.07f,0.13f));
        foreach (Collider c in root.GetComponentsInChildren<Collider>()) c.enabled = false;
        return root;
    }

    void BuildCamera()
    {
        gameCamera = Camera.main;
        if (!gameCamera)
        {
            GameObject cam = new GameObject("Main Camera");
            cam.tag = "MainCamera";
            gameCamera = cam.AddComponent<Camera>();
        }
        gameCamera.fieldOfView = 62f;
        gameCamera.nearClipPlane = 0.1f;
        gameCamera.farClipPlane = 150f;
        UpdateCamera();
    }

    void BuildLighting()
    {
        RenderSettings.ambientLight = new Color(0.55f,0.58f,0.66f);
        GameObject lightObj = new GameObject("Anime Stadium Sun");
        Light light = lightObj.AddComponent<Light>();
        light.type = LightType.Directional;
        light.intensity = 1.2f;
        lightObj.transform.rotation = Quaternion.Euler(48,-35,0);
    }

    void UpdateUser()
    {
        if (!userPlayer) return;
        Vector3 direction = new Vector3(moveInput.x,0,moveInput.y);
        if (direction.sqrMagnitude > 1f) direction.Normalize();
        float speed = sprintHeld ? 8f : 5.1f;
        userPlayer.position += direction * speed * Time.deltaTime;
        userPlayer.position = new Vector3(Mathf.Clamp(userPlayer.position.x,-10.5f,10.5f),0,Mathf.Clamp(userPlayer.position.z,-17.5f,17.5f));
        if (direction.sqrMagnitude > 0.01f) userPlayer.rotation = Quaternion.Slerp(userPlayer.rotation, Quaternion.LookRotation(direction), 12f * Time.deltaTime);
        if (Vector3.Distance(userPlayer.position, ball.transform.position) < 1.7f && ball.transform.position.y < 1.7f)
        {
            Vector3 nudge = userPlayer.forward * 2.5f;
            ballBody.AddForce(nudge, ForceMode.Acceleration);
        }
    }

    void UpdateAI()
    {
        foreach (PlayerAgent p in players)
        {
            if (p.user) continue;
            Vector3 target;
            bool chasing = Vector3.Distance(p.transform.position, ball.transform.position) < (p.team == 1 ? 10f : 7f);
            if (chasing) target = new Vector3(ball.transform.position.x,0,ball.transform.position.z);
            else
            {
                int slot = (p.transform.name.EndsWith("2") ? 1 : p.transform.name.EndsWith("3") ? 2 : 3);
                float z = p.team == 0 ? -5f + slot * 2.2f : 5f - slot * 2.2f;
                target = new Vector3(slot % 2 == 0 ? 4f : -4f,0,z);
            }
            Vector3 delta = target - p.transform.position;
            delta.y = 0;
            if (delta.magnitude > 0.8f)
            {
                Vector3 step = delta.normalized * p.speed * Time.deltaTime;
                p.transform.position += step;
                p.transform.position = new Vector3(Mathf.Clamp(p.transform.position.x,-10.5f,10.5f),0,Mathf.Clamp(p.transform.position.z,-17.5f,17.5f));
                p.transform.rotation = Quaternion.Slerp(p.transform.rotation,Quaternion.LookRotation(delta),8f*Time.deltaTime);
            }
            if (chasing && Vector3.Distance(p.transform.position,ball.transform.position) < 1.6f && Time.time > p.thinkOffset + 1.5f)
            {
                Vector3 goal = new Vector3(0,0,p.team == 0 ? 18 : -18);
                Vector3 shot = (goal - ball.transform.position).normalized;
                ballBody.AddForce((shot * 8f + Vector3.up * 2f),ForceMode.Impulse);
                p.thinkOffset = Time.time;
            }
        }
    }

    void UpdateCamera()
    {
        if (!gameCamera || !userPlayer) return;
        Vector3 desired = userPlayer.position - userPlayer.forward * 7f + Vector3.up * 4.4f;
        gameCamera.transform.position = Vector3.Lerp(gameCamera.transform.position,desired,8f*Time.deltaTime);
        gameCamera.transform.LookAt(userPlayer.position + userPlayer.forward * 3f + Vector3.up * 1f);
    }

    void KickBall(float power, float lift)
    {
        if (!userPlayer || Vector3.Distance(userPlayer.position,ball.transform.position) > 2.8f) return;
        Vector3 aim = (userPlayer.forward + Vector3.up * lift).normalized;
        ballBody.AddForce(aim * power,ForceMode.Impulse);
    }

    void PassBall()
    {
        if (!userPlayer || Vector3.Distance(userPlayer.position,ball.transform.position) > 2.8f) return;
        PlayerAgent best = null;
        float distance = float.MaxValue;
        foreach (PlayerAgent p in players)
        {
            if (p.team != 0 || p.user) continue;
            float d = Vector3.Distance(userPlayer.position,p.transform.position);
            if (d < distance) { distance = d; best = p; }
        }
        Vector3 aim = best ? (best.transform.position - ball.transform.position).normalized : userPlayer.forward;
        ballBody.AddForce(aim * 8f + Vector3.up * 1.2f,ForceMode.Impulse);
    }

    void UseUltimate()
    {
        abilityReadyAt = Time.time + 12f;
        if (!userPlayer) return;
        if (Vector3.Distance(userPlayer.position,ball.transform.position) < 3.2f)
            ballBody.AddForce((userPlayer.forward * 20f + Vector3.up * 5f),ForceMode.Impulse);
        else
            userPlayer.position += userPlayer.forward * 2.5f;
    }

    void CheckGoal()
    {
        Vector3 p = ball.transform.position;
        if (Mathf.Abs(p.x) < 3f && p.y < 2.4f)
        {
            if (p.z > 18f) { blueScore++; ResetKickoff(); if (cutscenes != null) cutscenes.PlayGoal(); }
            else if (p.z < -18f) { redScore++; ResetKickoff(); if (cutscenes != null) cutscenes.PlayGoal(); }
        }
        if (Mathf.Abs(p.x) > 12f || Mathf.Abs(p.z) > 21f || p.y < -4f) ResetBall();
    }

    void ResetKickoff()
    {
        ball.transform.position = new Vector3(0,0.6f,0);
        ballBody.velocity = Vector3.zero;
        ballBody.angularVelocity = Vector3.zero;
        foreach (PlayerAgent p in players)
        {
            int index = players.IndexOf(p) % 4;
            p.transform.position = new Vector3(index == 1 ? -4 : index == 2 ? 4 : 0,0,(p.team == 0 ? -1 : 1) * (index == 0 ? 7 : index == 3 ? 1 : 3));
        }
    }

    void ResetBall()
    {
        ball.transform.position = new Vector3(0,0.6f,0);
        ballBody.velocity = Vector3.zero;
        ballBody.angularVelocity = Vector3.zero;
    }

    void OnGUI()
    {
        if (titleStyle == null)
        {
            titleStyle = new GUIStyle(GUI.skin.label) { fontSize = 24, fontStyle = FontStyle.Bold, alignment = TextAnchor.MiddleCenter };
            titleStyle.normal.textColor = Color.white;
            scoreStyle = new GUIStyle(titleStyle) { fontSize = 32 };
            buttonStyle = new GUIStyle(GUI.skin.button) { fontSize = 19, fontStyle = FontStyle.Bold };
        }
        float w = Screen.width, h = Screen.height;
        GUI.Box(new Rect(w*0.34f,8,w*0.32f,76),"");
        GUI.Label(new Rect(w*0.34f,10,w*0.32f,42),"ECLIPSE STRIKERS",titleStyle);
        GUI.Label(new Rect(w*0.34f,46,w*0.32f,34),blueScore+"  -  "+redScore+"     "+FormatTime(timeLeft),scoreStyle);

        if (matchEnded)
        {
            GUI.Box(new Rect(w*0.25f,h*0.35f,w*0.5f,h*0.28f),"");
            GUI.Label(new Rect(w*0.25f,h*0.38f,w*0.5f,55),blueScore == redScore ? "FULL TIME — DRAW" : (blueScore > redScore ? "FULL TIME — BLUE WINS" : "FULL TIME — RED WINS"),titleStyle);
            if (GUI.Button(new Rect(w*0.4f,h*0.52f,w*0.2f,55),"PLAY AGAIN",buttonStyle))
            { blueScore = redScore = 0; timeLeft = MatchLength; matchEnded = false; ResetKickoff(); }
            return;
        }

        // Touch/drag joystick: keep finger inside the left lower quadrant.
        Rect stickArea = new Rect(18,h-205,180,180);
        GUI.Box(stickArea,"MOVE");
        Event e = Event.current;
        if (e.type == EventType.MouseDown || e.type == EventType.MouseDrag)
        {
            if (stickArea.Contains(e.mousePosition))
            {
                Vector2 centre = new Vector2(stickArea.x+90,stickArea.y+90);
                Vector2 v = (e.mousePosition-centre)/65f;
                moveInput = Vector2.ClampMagnitude(new Vector2(v.x,-v.y),1f);
            }
        }
        if (e.type == EventType.MouseUp) moveInput = Vector2.zero;
        if (GUI.Button(new Rect(w-150,h-112,132,88),"SHOOT")) shootPressed = true;
        if (GUI.Button(new Rect(w-292,h-112,132,88),"PASS")) passPressed = true;
        sprintHeld = GUI.RepeatButton(new Rect(w-150,h-210,132,78),"SPRINT");
        if (GUI.Button(new Rect(w-292,h-210,132,78),Time.time >= abilityReadyAt ? "ULTIMATE" : "COOLDOWN")) abilityPressed = true;
    }

    string FormatTime(float seconds)
    {
        int s = Mathf.CeilToInt(seconds);
        return (s/60).ToString("00")+":"+(s%60).ToString("00");
    }

    GameObject CreateCube(string name, Vector3 pos, Vector3 scale, Color color)
    {
        GameObject g = GameObject.CreatePrimitive(PrimitiveType.Cube);
        g.name = name; g.transform.position = pos; g.transform.localScale = scale; SetColor(g,color); return g;
    }

    void Line(string name, Vector3 a, Vector3 b, float width)
    {
        GameObject g = CreateCube(name,(a+b)*0.5f,new Vector3(width,width,Vector3.Distance(a,b)),Color.white);
        g.transform.rotation = Quaternion.LookRotation(b-a);
    }

    void SetColor(GameObject g, Color color)
    {
        Renderer r = g.GetComponent<Renderer>();
        if (r) { r.material = new Material(Shader.Find("Universal Render Pipeline/Lit") ?? Shader.Find("Standard")); r.material.color = color; }
    }
}
