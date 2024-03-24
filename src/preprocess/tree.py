class TreeNode:
    def __init__(self, data):
        self.data = data
        self.left = None  
        self.right = None  

    def add_left_child(self, child_node):
        self.left = child_node

    def add_right_child(self, child_node):
        self.right = child_node

    def __str__(self):
        return self._str_helper("", True)

    def _str_helper(self, prefix, is_tail):
        result = ""
        if self.right is not None:
            result += self.right._str_helper(prefix + ("│   " if is_tail else "    "), False)
        result += prefix + ("└── " if is_tail else "┌── ") + str(self.data) + "\n"
        if self.left is not None:
            result += self.left._str_helper(prefix + ("    " if is_tail else "│   "), True)
        return result


class Tree:
    def __init__(self, root_data):
        self.root = TreeNode(root_data)

    def traverse(self):
        def traverse_helper(node):
            if node is not None:
                print(node.data)
                traverse_helper(node.left)
                traverse_helper(node.right)

        traverse_helper(self.root)

    def __str__(self):
        return str(self.root)

def are_isomorphic(root1, root2):
    if root1 is None and root2 is None:
        return True
    
    if root1 is None or root2 is None:
        return False
    
    if root1.data != root2.data:
        return False
    
    return (are_isomorphic(root1.left, root2.left) and
            are_isomorphic(root1.right, root2.right))


if __name__ == "__main__":
    root1 = TreeNode(1)
    root1.left = TreeNode(2)
    root1.right = TreeNode(3)
    root1.left.left = TreeNode(4)
    root1.left.right = TreeNode(5)
    root1.right.left = TreeNode(6)
    root1.right.right = TreeNode(7)

    root2 = TreeNode(1)
    root2.left = TreeNode(3)
    root2.right = TreeNode(2)
    root2.left.left = TreeNode(7)
    root2.left.right = TreeNode(6)
    root2.right.left = TreeNode(5)
    root2.right.right = TreeNode(4)

    if are_isomorphic(root1, root2):
        print("yes")
    else:
        print("no")

    print(root1)
    print(root2)
