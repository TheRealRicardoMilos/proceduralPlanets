using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class RayMarchCamera : SceneViewFilter
{
    [SerializeField] 
    private Shader shader;

    private Material rayMarchMat;

    public Material rayMarchMaterial
    {
        get
        {
            if (!rayMarchMat && shader)
            {
                rayMarchMat = new Material(shader);
                rayMarchMat.hideFlags = HideFlags.HideAndDontSave;
            }
            return rayMarchMat;
        }
    }

    private Camera cam;

    public Transform directionalLight;

    public float maxDistance;
    public Vector4 sphere1;

    public Camera Camera
    {
        get 
        {
            if(!cam)
            {
                cam = GetComponent<Camera>();
            }
            return cam;
        }
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (!rayMarchMaterial)
        {
            Graphics.Blit(source, destination);
            return;
        }
        rayMarchMaterial.SetVector("lightPosition", directionalLight ? directionalLight.position : Vector3.down);
        rayMarchMaterial.SetMatrix("CamFrustum", CamFrustum(Camera));
        rayMarchMaterial.SetMatrix("CamToWorld", Camera.cameraToWorldMatrix);
        rayMarchMaterial.SetFloat("maxDistance", maxDistance);
        rayMarchMaterial.SetVector("sphere1", sphere1);
        

        RenderTexture.active = destination;
        rayMarchMaterial.SetTexture("_MainTex",source);

        GL.PushMatrix();
        GL.LoadOrtho();
        rayMarchMaterial.SetPass(0);
        GL.Begin(GL.QUADS);

        //BL
        GL.MultiTexCoord2(0,0.0f,0.0f);
        GL.Vertex3(0.0f,0.0f,3.0f);
        //BR
        GL.MultiTexCoord2(0,1.0f,0.0f);
        GL.Vertex3(1.0f,0.0f,2.0f);
        //TR
        GL.MultiTexCoord2(0,1.0f,1.0f);
        GL.Vertex3(1.0f,1.0f,1.0f);
        //TL
        GL.MultiTexCoord2(0,0.0f,1.0f);
        GL.Vertex3(0.0f,1.0f,0.0f);

        GL.End();
        GL.PopMatrix();
    }

    private Matrix4x4 CamFrustum(Camera cam)
    {
        Matrix4x4 frustum = Matrix4x4.identity;
        float fov = Mathf.Tan((cam.fieldOfView * 0.5f) * Mathf.Deg2Rad);

        Vector3 goUp = Vector3.up * fov;
        Vector3 goRight = Vector3.right * fov * cam.aspect;

        Vector3 TL = (-Vector3.forward - goRight + goUp);
        Vector3 TR = (-Vector3.forward + goRight + goUp);
        Vector3 BR = (-Vector3.forward + goRight - goUp);
        Vector3 BL = (-Vector3.forward - goRight - goUp);

        frustum.SetRow(0, TL);
        frustum.SetRow(1, TR);
        frustum.SetRow(2, BR);
        frustum.SetRow(3, BL);

        return frustum;
    }
}
