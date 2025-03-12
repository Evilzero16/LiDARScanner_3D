import open3d as o3d

# Load the point cloud file
pcd = o3d.io.read_point_cloud("pointclouds/pointcloud.ply")

pcd.scale(10, center=pcd.get_center())  # Adjust scaling factor as needed

# Visualize the point cloud
o3d.visualization.draw_geometries([pcd])