using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;


public class PlanetMesh : MonoBehaviour
{
    private Mesh mesh;
    public List<Vector3> vertices;
    public List<int> triangles;
    private List<Vector2> uv;

    public int subdivisions = 3;
    private int prevSubdivisions;
    public float radius = 1f;
    public float MountainHeight = 0.2f;
    public float MountainSize = 0.5f;
    public float InitialFactor = 5f;
    public float Offset;

    private void Start()
    {
        GenerateMesh();
    }

    private void OnValidate()
    {
        //GenerateMesh();
        CreateUVs();
    }

    private void GenerateMesh()
    {
        mesh = new Mesh();
        GenerateOctohedronVertices();
        GenerateOctohedronTriangles();
        ProjectToTerrain();
        CreateUVs();

        
        mesh.vertices = vertices.ToArray();
        mesh.triangles = triangles.ToArray();
        mesh.uv = uv.ToArray();
        mesh.RecalculateNormals();

        GetComponent<MeshFilter>().mesh = mesh;
    }
    private void GenerateOctohedronVertices()
    {
        int n = subdivisions + 1;

        List<Vector3> positions = new List<Vector3>();
        List<Vector3> nPositions = new List<Vector3>();

        for (int j = 0; j < n; j++)
        {
            // Outer bounds
            float absXPos = 0.5f * (1 - j / (float)n);
            float layerYPos = (float)Mathf.Sqrt(1.5f) * j / (float)n;
            float absZPos = absXPos;

            positions.AddRange(new List<Vector3>
            {
                
                new Vector3(absXPos, layerYPos, absZPos),
                new Vector3(absXPos, layerYPos, -absZPos),
                new Vector3(-absXPos, layerYPos, -absZPos),
                new Vector3(-absXPos, layerYPos, absZPos)
            });

            if (j != 0)
            {
                nPositions.AddRange(new List<Vector3>
                {
                    new Vector3(absXPos, -layerYPos, absZPos),
                    new Vector3(absXPos, -layerYPos, -absZPos),
                    new Vector3(-absXPos, -layerYPos, -absZPos),
                    new Vector3(-absXPos, -layerYPos, absZPos)
                });
            }

            // 4 triangle faces
            for (int i = 0; i < n - j - 1; i++)
            {
                float posOnFace = 0.5f - (i + j / 2.0f + 1) / n;

                positions.AddRange(new List<Vector3>
                {
                    new Vector3(absZPos, layerYPos, posOnFace),
                    new Vector3(posOnFace, layerYPos, -absZPos),
                    new Vector3(-absZPos, layerYPos, -posOnFace),
                    new Vector3(-posOnFace, layerYPos, absZPos)
                });

                if (j != 0)
                {
                    nPositions.AddRange(new List<Vector3>
                    {
                        new Vector3(absZPos, -layerYPos, posOnFace),
                        new Vector3(posOnFace, -layerYPos, -absZPos),
                        new Vector3(-absZPos, -layerYPos, -posOnFace),
                        new Vector3(-posOnFace, -layerYPos, absZPos)
                    });
                }
            }
        }

        positions.AddRange(nPositions);

        positions.Add(new Vector3(0, (float)Mathf.Sqrt(1.5f), 0));
        positions.Add(new Vector3(0, -(float)Mathf.Sqrt(1.5f), 0));

        // Output the positions for verification
        vertices = positions;
    }

    private void GenerateOctohedronTriangles()
    {
        triangles = new List<int>();
        List<int> bottomTriangles = new List<int>();
        List<int> tempTriangles = new List<int>();
        int bottomOffSet = sumUpTo(subdivisions);
        int trueBottomOffSet = bottomOffSet*4;

        int sumUpTo(int n)
        {
            if (n <= 0) {return 0;}
            int sum = 0;
            for (int i = 1; i <= n; i++)
            {
                sum += i;
            }
            return sum;
        }

        int f(int n)
        {
            return (subdivisions+1)*n - sumUpTo(n-1);
        }

        for (int j = 0; j < subdivisions; j++)
        {
            for (int i = 0; i < (subdivisions-j); i++)
            {
                
                tempTriangles.AddRange(new int[] {f(j)+i,f(j)+i+1,f(j+1)+i});
                if (j!=0)
                {
                    
                    tempTriangles.AddRange(new int[] {f(j)+i,f(j-1)+i+1,f(j)+i+1});
                    bottomTriangles.AddRange(new int[] {f(j)+i + bottomOffSet,f(j+1)+i + bottomOffSet,f(j)+i+1 + bottomOffSet});
                    if (j!= 1)
                    {
                        bottomTriangles.AddRange(new int[] {f(j)+i + bottomOffSet,f(j)+i+1 + bottomOffSet,f(j-1)+i+1 + bottomOffSet});
                    }
                    else
                    {
                        bottomTriangles.AddRange(new int[] {f(j)+i + bottomOffSet,f(j)+i+1 + bottomOffSet,f(j-1)+i+1});
                    }
                }
                else
                {
                    bottomTriangles.AddRange(new int[] {f(j)+i,f(j+1) + i + bottomOffSet,f(j)+i+1});
                }
            }
        }

        for (int k = 0; k < tempTriangles.Count; k++)
        {
            tempTriangles[k] *= 4;
        }
        for (int k = 0; k < bottomTriangles.Count; k++)
        {
            bottomTriangles[k] *= 4;
        }

        
        int last(int n)// last number of triangle that touches edge
        {
            int sum = 0;
            int startValue = subdivisions+1;
            for (int i = 0; i < (n + 1); i++)
            {
                sum += startValue - i;
            }
            
            return 4 * (sum-1);
        }

        for (int j = 0; j < subdivisions+1; j++)//setting edge triangles
        {
            if (j!=subdivisions)
            {
                tempTriangles.AddRange(new int[] {4*f(j+1)+1,last(j),4*f(j)+1});
            }
            if (j!=0)
            {
                tempTriangles.AddRange(new int[] {last(j-1),4*f(j)+1,last(j)});
                if (j!=subdivisions)
                {
                    bottomTriangles.AddRange(new int[] {4*f(j+1)+1 + trueBottomOffSet,4*f(j)+1 + trueBottomOffSet,last(j) + trueBottomOffSet});
                }
                if (j!=1)
                {
                    bottomTriangles.AddRange(new int[] {last(j-1) + trueBottomOffSet,last(j) + trueBottomOffSet,4*f(j)+1 + trueBottomOffSet});
                }
                else
                {
                    bottomTriangles.AddRange(new int[] {last(j-1),last(j) + trueBottomOffSet,4*f(j)+1 + trueBottomOffSet});
                }
            }
            else
            {
                bottomTriangles.AddRange(new int[] {4*f(j+1)+1 + trueBottomOffSet,4*f(j)+1,last(j)});
            }
        }

        triangles.AddRange(tempTriangles);
        triangles.AddRange(bottomTriangles);
        
        int Count = tempTriangles.Count;

        for (int i = 0; i < 3; i++)
        {
            if (i == 2)
            {
                tempTriangles.RemoveRange(Count-subdivisions*6, subdivisions*6);
                bottomTriangles.RemoveRange(Count-subdivisions*6, subdivisions*6);
                Count = tempTriangles.Count;

                for (int k = 0; k < Count; k++)
                {
                    tempTriangles[k] += 1;
                }

                for (int k = 0; k < Count; k++)
                {
                    bottomTriangles[k] += 1;
                }

                

                for (int j = 0; j < subdivisions+1; j++)
                {
                    if (j!=subdivisions)
                    {
                        tempTriangles.AddRange(new int[] {4*f(j+1),last(j)+3,4*f(j)});
                    }
                    if (j!=0)
                    {
                        tempTriangles.AddRange(new int[] {last(j-1)+3,4*f(j),last(j)+3});
                        if (j!=subdivisions)
                        {
                            bottomTriangles.AddRange(new int[] {4*f(j+1) + trueBottomOffSet,4*f(j) + trueBottomOffSet,last(j)+3 + trueBottomOffSet});
                        }
                        if (j!=1)
                        {
                            bottomTriangles.AddRange(new int[] {last(j-1)+3 + trueBottomOffSet,last(j)+3 + trueBottomOffSet,4*f(j) + trueBottomOffSet});
                        }
                        else
                        {
                            tempTriangles.AddRange(new int[] {last(j-1)+3,last(j)+3 + trueBottomOffSet,4*f(j) + trueBottomOffSet});
                        }
                    }
                    else
                    {
                        tempTriangles.AddRange(new int[] {4*f(j+1) + trueBottomOffSet,4*f(j),last(j)+3});
                    }
                }
                triangles.AddRange(tempTriangles);
                triangles.AddRange(bottomTriangles);
            }
            else
            {
                for (int k = 0; k < Count; k++)
                {
                    tempTriangles[k] += 1;
                }
                triangles.AddRange(tempTriangles);
                for (int k = 0; k < Count; k++)
                {
                    bottomTriangles[k] += 1;
                }
                triangles.AddRange(bottomTriangles);
                
            }
        }
        int top = vertices.Count-1;
        addTip(f(subdivisions)*4,top-1,false);
        addTip(f(subdivisions)*4 + trueBottomOffSet,top,true);

        void addTip(int first,int top,bool isInverse)
        {
            if (isInverse)
            {
                triangles.AddRange(new int[] 
                {
                    first,top,first+1,
                    first+1,top,first+2,
                    first+2,top,first+3,
                    first+3,top,first
                });
            }
            else
            {
                triangles.AddRange(new int[] 
                {
                    first,first+1,top,
                    first+1,first+2,top,
                    first+2,first+3,top,
                    first+3,first,top
                });
            }
        }
        //bottom layer
    }
    private void ProjectToTerrain()
    {

        for (int i = 0; i < vertices.Count; i++)
        {
            Vector3 normalizedVertex = vertices[i].normalized;
            float height = Height(vertices[i].normalized + new Vector3(Offset,Offset,Offset));
            vertices[i] = normalizedVertex * height;
        }
    }

    private float Height(Vector3 position)
    {
        //layer1
        var (height1, gradient1) = Noised(position * MountainSize);
        float gradientMag1 = gradient1.magnitude*4f;
        float erosionLevel1 = 1/(1+gradientMag1);
        float layer1 = height1 * erosionLevel1;
        //layer2
        Vector3 layer2Offset = new Vector3(5f,5f,5f);
        float layer2Size = 5f * MountainSize;
        float layer2height = 0.3f;
        var (height2, gradient2) = Noised(position * layer2Size + layer2Offset);
        float gradientMag2 = gradient2.magnitude*4f;
        float erosionLevel2= 1/(1+gradientMag1+gradientMag2);
        float layer2 = (height2 + radius/4f) * layer2height * erosionLevel2;
        //layer3
        Vector3 layer3Offset = new Vector3(5f,5f,5f) + layer2Offset;
        float layer3Size = 5f * layer2Size;
        float layer3height = 0.8f * layer2height;
        var (height3, gradient3) = Noised(position * layer3Size + layer3Offset);
        float gradientMag3 = gradient3.magnitude*4f;
        float erosionLevel3= 1/(1+gradientMag1+gradientMag2+gradientMag3);
        float layer3 = height3 * layer3height * erosionLevel3;
        return (layer1+layer2+layer3)*MountainHeight+radius;
    }


    private void CreateUVs()
    {
        float textureScale = 5.0f;
        uv = new List<Vector2>();
        foreach (var vertex in vertices)
        {
            Vector3 normalizedVertex = vertex.normalized;
            float u = 0.5f + (Mathf.Atan2(vertex.z, vertex.x) / (2 * Mathf.PI));
            float v = 0.5f - (Mathf.Asin(vertex.y) / Mathf.PI);
            u *= textureScale;
            v *= textureScale;
            uv.Add(new Vector2(u, v));
        }
    }


    //credit: https://iquilezles.org/articles/gradientnoise/
    private (float,Vector3) Noised(Vector3 x)
    {
        // grid
        Vector3 p = new Vector3(Mathf.Floor(x.x), Mathf.Floor(x.y), Mathf.Floor(x.z));
        Vector3 w = new Vector3(x.x - p.x, x.y - p.y, x.z - p.z);
    
        // quintic interpolant
        Vector3 u = Vector3.Scale(w, Vector3.Scale(w, Vector3.Scale(w, Vector3.Scale(w, Vector3.Scale(w, new Vector3(6.0f, 6.0f, 6.0f)) - new Vector3(15.0f, 15.0f, 15.0f)) + new Vector3(10.0f, 10.0f, 10.0f))));
        Vector3 du = Vector3.Scale(30.0f * w, Vector3.Scale(w, Vector3.Scale(w, Vector3.Scale(w, Vector3.Scale(w, new Vector3(1.0f, 1.0f, 1.0f)) - new Vector3(2.0f, 2.0f, 2.0f)) + new Vector3(1.0f, 1.0f, 1.0f))));
    
        // gradients
        Vector3 ga = hash(p + new Vector3(0.0f, 0.0f, 0.0f));
        Vector3 gb = hash(p + new Vector3(1.0f, 0.0f, 0.0f));
        Vector3 gc = hash(p + new Vector3(0.0f, 1.0f, 0.0f));
        Vector3 gd = hash(p + new Vector3(1.0f, 1.0f, 0.0f));
        Vector3 ge = hash(p + new Vector3(0.0f, 0.0f, 1.0f));
        Vector3 gf = hash(p + new Vector3(1.0f, 0.0f, 1.0f));
        Vector3 gg = hash(p + new Vector3(0.0f, 1.0f, 1.0f));
        Vector3 gh = hash(p + new Vector3(1.0f, 1.0f, 1.0f));
    
        // projections
        float va = Vector3.Dot(ga, w - new Vector3(0.0f, 0.0f, 0.0f));
        float vb = Vector3.Dot(gb, w - new Vector3(1.0f, 0.0f, 0.0f));
        float vc = Vector3.Dot(gc, w - new Vector3(0.0f, 1.0f, 0.0f));
        float vd = Vector3.Dot(gd, w - new Vector3(1.0f, 1.0f, 0.0f));
        float ve = Vector3.Dot(ge, w - new Vector3(0.0f, 0.0f, 1.0f));
        float vf = Vector3.Dot(gf, w - new Vector3(1.0f, 0.0f, 1.0f));
        float vg = Vector3.Dot(gg, w - new Vector3(0.0f, 1.0f, 1.0f));
        float vh = Vector3.Dot(gh, w - new Vector3(1.0f, 1.0f, 1.0f));
	
        // interpolation
        float v = va + 
                  u.x * (vb - va) + 
                  u.y * (vc - va) + 
                  u.z * (ve - va) + 
                  u.x * u.y * (va - vb - vc + vd) + 
                  u.y * u.z * (va - vc - ve + vg) + 
                  u.z * u.x * (va - vb - ve + vf) + 
                  u.x * u.y * u.z * (-va + vb + vc - vd + ve - vf - vg + vh);
              
        Vector3 d = ga + 
                    u.x * (gb - ga) + 
                    u.y * (gc - ga) + 
                    u.z * (ge - ga) + 
                    u.x * u.y * (ga - gb - gc + gd) + 
                    u.y * u.z * (ga - gc - ge + gg) + 
                    u.z * u.x * (ga - gb - ge + gf) + 
                    u.x * u.y * u.z * (-ga + gb + gc - gd + ge - gf - gg + gh) +   
                     
                    Vector3.Scale(du, (Vector3.Scale(new Vector3(vb - va, vc - va, ve - va), Vector3.one)) + 
                        Vector3.Scale(new Vector3(u.y, u.z, u.x), new Vector3(va - vb - vc + vd, va - vc - ve + vg, va - vb - ve + vf)) + 
                        Vector3.Scale(new Vector3(u.z, u.x, u.y), new Vector3(va - vb - ve + vf, va - vb - vc + vd, va - vc - ve + vg)) + 
                        new Vector3(u.y, u.z, u.x) * (-va + vb + vc - vd + ve - vf - vg + vh));
                   
        return (v,d);
    }

    //credit: https://www.shadertoy.com/view/4dffRH
    Vector3 hash(Vector3 p)
    {
        Vector3 dotProduct1 = new Vector3(127.1f, 311.7f, 74.7f);
        Vector3 dotProduct2 = new Vector3(269.5f, 183.3f, 246.1f);
        Vector3 dotProduct3 = new Vector3(113.5f, 271.9f, 124.6f);

        p = new Vector3(Vector3.Dot(p, dotProduct1),
                        Vector3.Dot(p, dotProduct2),
                        Vector3.Dot(p, dotProduct3));

        return new Vector3(-1.0f,-1.0f,-1.0f) + 2.0f * vec3Fract(new Vector3(Mathf.Sin(p.x),Mathf.Sin(p.y),Mathf.Sin(p.z)) * 43758.5453123f);
    }

    float fract(float x)
    {
        return x - Mathf.Floor(x);
    }

    Vector3 vec3Fract(Vector3 v)
    {
        return new Vector3(fract(v.x), fract(v.y), fract(v.z));
    }

    private void OnDrawGizmos()
    {
        if (vertices == null) {
            return;
        }
        for (int i = 0; i < vertices.Count; i++) {
            Gizmos.color = Color.black;
            Gizmos.DrawSphere(transform.TransformPoint(vertices[i]), 0.1f);
        }
    }
}


