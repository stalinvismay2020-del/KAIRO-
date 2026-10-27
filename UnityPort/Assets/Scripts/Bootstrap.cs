using UnityEngine;

public static class EclipseStrikersBootstrap
{
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void CreateGameIfMissing()
    {
        if (Object.FindObjectOfType<EclipseStrikersGame>() != null) return;
        GameObject root = new GameObject("Eclipse Strikers Runtime");
        root.AddComponent<EclipseStrikersGame>();
    }
}
