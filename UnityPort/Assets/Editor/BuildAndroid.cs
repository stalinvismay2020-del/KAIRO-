using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

public static class EclipseStrikersAndroidBuilder
{
    [MenuItem("Eclipse Strikers/Build Android Debug APK")]
    public static void BuildAndroidDebugApk()
    {
        const string output = "Builds/EclipseStrikers-debug.apk";
        Directory.CreateDirectory("Builds");

        EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android);
        PlayerSettings.companyName = "Eclipse Strikers Studio";
        PlayerSettings.productName = "Eclipse Strikers";
        PlayerSettings.applicationIdentifier = "com.eclipse.strikers";
        PlayerSettings.defaultInterfaceOrientation = UIOrientation.LandscapeLeft;
        PlayerSettings.SetScriptingBackend(BuildTargetGroup.Android, ScriptingImplementation.IL2CPP);
        EditorUserBuildSettings.buildAppBundle = false;

        BuildPlayerOptions options = new BuildPlayerOptions
        {
            scenes = new[] { "Assets/Scenes/Main.unity" },
            locationPathName = output,
            target = BuildTarget.Android,
            options = BuildOptions.Development
        };

        BuildReport report = BuildPipeline.BuildPlayer(options);
        if (report.summary.result != BuildResult.Succeeded)
            throw new Exception("Eclipse Strikers APK build failed: " + report.summary.result + ". Check Unity Editor.log for details.");

        Debug.Log("APK build succeeded: " + Path.GetFullPath(output) + " (" + report.summary.totalSize + " bytes)");
    }
}
